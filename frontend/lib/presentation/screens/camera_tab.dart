import 'package:flutter/foundation.dart';

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/ocr_parser.dart';
import '../../core/utils/toast_service.dart';
import '../../domain/entities/verification_result.dart';
import '../../domain/entities/payment_account.dart';
import '../../theme/app_tokens.dart';
import '../providers/payment_provider.dart';
import '../widgets/sv_loader.dart';

class CameraTab extends ConsumerStatefulWidget {
  const CameraTab({super.key, this.isActive = true});

  final bool isActive;

  @override
  ConsumerState<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends ConsumerState<CameraTab> {
  static const _cameraPermissionAskedKey = 'snapverify.camera_permission_asked';

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  bool _torchOn = false;
  bool _processing = false;
  bool _checkingPermission = false;
  String? _initError;
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initCamera();
  }

  @override
  void didUpdateWidget(covariant CameraTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && !_initialized) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (_checkingPermission || _initialized) return;
    _checkingPermission = true;
    debugPrint('[CameraTab] Initializing camera...');
    try {
      final prefs = await SharedPreferences.getInstance();
      PermissionStatus status = await Permission.camera.status;
      final askedBefore = prefs.getBool(_cameraPermissionAskedKey) ?? false;

      if (!status.isGranted) {
        if (askedBefore) {
          _setPermissionError(status);
          return;
        }
        await prefs.setBool(_cameraPermissionAskedKey, true);
        status = await Permission.camera.request();
      }
      if (!status.isGranted) {
        _setPermissionError(status);
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('[CameraTab] No cameras found');
        if (mounted)
          setState(() => _initError = 'No camera found on this device');
        return;
      }

      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      debugPrint('[CameraTab] Using camera: ${back.name}');

      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await ctrl.initialize();
      debugPrint('[CameraTab] Camera initialized successfully');

      if (!mounted) return;
      _controller = ctrl;
      setState(() {
        _initialized = true;
        _initError = null;
      });
    } catch (e, stackTrace) {
      debugPrint('[CameraTab] Camera initialization error: $e');
      debugPrint('[CameraTab] Stack trace: $stackTrace');
      if (mounted) setState(() => _initError = 'Camera error: $e');
    } finally {
      _checkingPermission = false;
    }
  }

  void _setPermissionError(PermissionStatus status) {
    final permanent = status.isPermanentlyDenied;
    if (mounted) {
      setState(() {
        _initError = permanent
            ? 'Camera access is blocked. Open app settings to allow it.'
            : 'Camera permission is needed to scan receipts. Open app settings to allow it.';
      });
    }
  }

  Future<void> _openCameraSettings() async {
    await openAppSettings();
    if (mounted) _initCamera();
  }

  Future<void> _captureAndProcess() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _processing) return;

    final sw = Stopwatch()..start();
    setState(() => _processing = true);

    try {
      debugPrint('[CameraTab] Capturing image...');
      final XFile imageFile = await ctrl.takePicture();
      debugPrint('[CameraTab] Image captured in ${sw.elapsedMilliseconds}ms');

      final inputImage = InputImage.fromFilePath(imageFile.path);
      debugPrint('[CameraTab] Starting OCR processing...');
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      final ocrText = recognizedText.text;
      debugPrint(
        '[CameraTab] OCR complete in ${sw.elapsedMilliseconds}ms. Text length: ${ocrText.length}',
      );
      if (ocrText.isNotEmpty) {
        // Sanitized diagnostics: digit runs of 4+ are masked so payer names,
        // account/phone numbers and full references never reach the logs.
        debugPrint(
          '[CameraTab] OCR Text (sanitized): '
          '${ocrText.replaceAll('\n', ' | ').replaceAll(RegExp(r'\d{4,}'), '####')}',
        );
      }

      final transaction = OcrParser.extractTransaction(recognizedText);
      debugPrint(
        '[CameraTab] Extracted transaction at ${sw.elapsedMilliseconds}ms: ref=${OcrParser.maskReference(transaction?.referenceId)}, suffix=${transaction?.suffix == null ? null : 'present'}, amount=${transaction?.amount}, provider=${transaction?.provider}',
      );

      if (!mounted) return;
      if (transaction != null) {
        // Provider detection must be validated. If OCR is uncertain, ask the
        // user to select instead of guessing — never fall back to another
        // provider's registered account.
        final detected = paymentProviderFromOcrLabel(transaction.provider);
        PaymentProvider? selected = detected;
        if (selected == null) {
          selected = await _promptProviderSelection();
          if (selected == null) return; // user cancelled
        }
        if (!mounted) return;
        ref.read(paymentProvider.notifier).reset();
        ref
            .read(paymentProvider.notifier)
            .verifyReference(
              transaction.referenceId,
              amount: transaction.amount,
              provider: selected.name,
              suffix: transaction.suffix,
            );
        _showResultSheet(transaction);
      } else {
        _showInvalidReceiptDialog();
      }
    } catch (e, stackTrace) {
      debugPrint('[CameraTab] Error capturing/processing image: $e');
      debugPrint('[CameraTab] Stack trace: $stackTrace');
      ToastService.showError('Error: $e');
    } finally {
      sw.stop();
      if (mounted) setState(() => _processing = false);
    }
  }

  /// Ask the user to select the payment provider when OCR detection is
  /// uncertain. Returns null when the user dismisses the sheet (no guessing).
  Future<PaymentProvider?> _promptProviderSelection() {
    return showModalBottomSheet<PaymentProvider>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTokens.headerBase,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTokens.radiusField),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            AppTokens.sheetHorizontalPadding,
            AppTokens.spaceLg,
            AppTokens.sheetHorizontalPadding,
            AppTokens.space2xl + MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: AppTokens.logoIconSize,
                  height: AppTokens.handleHeight,
                  decoration: BoxDecoration(
                    color: AppTokens.inkMuted,
                    borderRadius: BorderRadius.circular(
                      AppTokens.progressStroke,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.space2xl),
              Text(
                'Select Payment Provider',
                style: AppTokens.manrope(
                  size: AppTokens.textSubtitle,
                  weight: FontWeight.w800,
                  color: AppTokens.white,
                ),
              ),
              const SizedBox(height: AppTokens.titleLanguageGap),
              Text(
                'We could not confidently detect the provider from this receipt. '
                'Choose the provider shown on the receipt.',
                style: AppTokens.dmSans(
                  size: AppTokens.textLabel,
                  weight: FontWeight.w400,
                  color: AppTokens.white.withValues(
                    alpha: AppTokens.alphaSecondary,
                  ),
                  height: AppTokens.lineHeightRelaxed,
                ),
              ),
              const SizedBox(height: AppTokens.spaceLg),
              ...PaymentProvider.values.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                  child: Material(
                    color: AppTokens.obsidian950,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.badgePaddingH,
                          vertical: AppTokens.badgePaddingH,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                          border: Border.all(
                            color: AppTokens.obsidian700,
                            width: AppTokens.componentBorderWidth,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_rounded,
                              color: AppTokens.accent,
                              size: AppTokens.formPrefixIconSize,
                            ),
                            const SizedBox(width: AppTokens.spaceMd),
                            Expanded(
                              child: Text(
                                provider.label,
                                style: AppTokens.manrope(
                                  size: AppTokens.textBody,
                                  weight: FontWeight.w500,
                                  color: AppTokens.white,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppTokens.textSecondary,
                              size: AppTokens.formPrefixIconSize,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInvalidReceiptDialog() {
    showDialog(
      context: context,
      barrierColor: AppTokens.obsidian950.withValues(
        alpha: AppTokens.alphaDisabled,
      ),
      builder: (context) => Dialog(
        backgroundColor: AppTokens.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppTokens.space2xl),
          decoration: BoxDecoration(
            color: AppTokens.obsidian950,
            borderRadius: BorderRadius.circular(AppTokens.radius2xl),
            border: Border.all(color: AppTokens.obsidian700),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTokens.inputPaddingH),
                decoration: BoxDecoration(
                  color: AppTokens.error.withValues(
                    alpha: AppTokens.alphaSubtle,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTokens.error,
                  size: AppTokens.logoIconSize,
                ),
              ),
              const SizedBox(height: AppTokens.inputPaddingH),
              Text(
                'Invalid Receipt',
                style: AppTokens.manrope(
                  size: AppTokens.textBodyLarge,
                  weight: FontWeight.w700,
                  color: AppTokens.white,
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                "We couldn't find a valid transaction in the captured image. "
                'Please make sure the receipt is clear and contains a '
                'transaction reference number.',
                textAlign: TextAlign.center,
                style: AppTokens.dmSans(
                  size: AppTokens.textLabel,
                  weight: FontWeight.w400,
                  color: AppTokens.ice400,
                  height: AppTokens.lineHeightRelaxed,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXl),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: AppTokens.statTileSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTokens.accent,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Text(
                    'Try Again',
                    style: AppTokens.manrope(
                      size: AppTokens.textBodySmall,
                      weight: FontWeight.w700,
                      color: AppTokens.ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultSheet(ExtractedTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _VerifyResultSheet(detectedTransaction: transaction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.obsidian950,
      body: _initError != null
          ? _ErrorView(
              message: _initError!,
              onRetry: _initCamera,
              onOpenSettings: _openCameraSettings,
            )
          : !_initialized
          ? const Center(child: SvLoader.page())
          : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    final ctrl = _controller!;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        SizedBox.expand(
          child: GestureDetector(
            onTap: _processing ? null : _captureAndProcess,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: ctrl.value.previewSize!.height,
                height: ctrl.value.previewSize!.width,
                child: CameraPreview(ctrl),
              ),
            ),
          ),
        ),

        if (_processing)
          Positioned.fill(
            child: Container(
              color: AppTokens.obsidian950.withValues(
                alpha: AppTokens.alphaTertiary,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SvLoader.page(),
                    const SizedBox(height: AppTokens.spaceLg),
                    Text(
                      'Reading receipt…',
                      style: AppTokens.dmSans(
                        size: AppTokens.textBodySmall,
                        weight: FontWeight.w400,
                        color: AppTokens.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceLg,
                  vertical: AppTokens.spaceLg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: AppTokens.languageItemHeight,
                          height: AppTokens.languageItemHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTokens.accent,
                                AppTokens.accent.withValues(
                                  alpha: AppTokens.alphaDisabled,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusSm,
                            ),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: AppTokens.ink,
                            size: AppTokens.errorIconSize,
                          ),
                        ),
                        const SizedBox(width: AppTokens.dropdownIconGap),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SnapVerify',
                              style: AppTokens.manrope(
                                size: AppTokens.textSubtitle,
                                weight: FontWeight.w800,
                                color: AppTokens.white,
                                letterSpacing: AppTokens.trackingTight,
                              ),
                            ),
                            Text(
                              'Capture receipt to verify',
                              style: AppTokens.dmSans(
                                size: AppTokens.textLabel,
                                weight: FontWeight.w400,
                                color: AppTokens.ice400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () async {
                        await ctrl.setFlashMode(
                          _torchOn ? FlashMode.off : FlashMode.torch,
                        );
                        setState(() => _torchOn = !_torchOn);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(
                          AppTokens.dropdownIconGap,
                        ),
                        decoration: BoxDecoration(
                          color: _torchOn
                              ? AppTokens.accent.withValues(
                                  alpha: AppTokens.navGlowAlpha,
                                )
                              : AppTokens.white.withValues(
                                  alpha: AppTokens.alphaSubtle,
                                ),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                          border: Border.all(
                            color: _torchOn
                                ? AppTokens.accent.withValues(
                                    alpha: AppTokens.alphaSecondary,
                                  )
                                : AppTokens.white.withValues(
                                    alpha: AppTokens.alphaMedium,
                                  ),
                            width: AppTokens.componentBorderWidth,
                          ),
                        ),
                        child: Icon(
                          _torchOn
                              ? Icons.flashlight_on_rounded
                              : Icons.flashlight_off_rounded,
                          color: _torchOn ? AppTokens.accent : AppTokens.white,
                          size: AppTokens.backButtonIconSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceLg,
                  vertical: AppTokens.space3xl,
                ),
                child: GestureDetector(
                  onTap: _processing ? null : _captureAndProcess,
                  child: Container(
                    width: AppTokens.patternTileHeight,
                    height: AppTokens.patternTileHeight,
                    decoration: BoxDecoration(
                      color: _processing
                          ? AppTokens.obsidian700
                          : AppTokens.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _processing
                            ? AppTokens.inkMuted
                            : AppTokens.accent.withValues(
                                alpha: AppTokens.alphaDisabled,
                              ),
                        width: AppTokens.focusRingWidth,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: _processing ? AppTokens.ice400 : AppTokens.ink,
                      size: AppTokens.space3xl,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space3xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTokens.spaceXl),
              decoration: BoxDecoration(
                color: AppTokens.error.withValues(alpha: AppTokens.alphaSubtle),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTokens.error.withValues(
                    alpha: AppTokens.alphaStrong,
                  ),
                ),
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                color: AppTokens.error,
                size: AppTokens.logoIconSize,
              ),
            ),
            const SizedBox(height: AppTokens.spaceXl),
            Text(
              message,
              style: AppTokens.dmSans(
                size: AppTokens.textBodySmall,
                weight: FontWeight.w400,
                color: AppTokens.white.withValues(
                  alpha: AppTokens.alphaPrimaryMuted,
                ),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceXl),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.accent,
                foregroundColor: AppTokens.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
              child: Text(
                'Retry',
                style: AppTokens.manrope(
                  size: AppTokens.buttonTextSize,
                  weight: FontWeight.w700,
                  color: AppTokens.ink,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.dropdownIconGap),
            TextButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(
                Icons.settings_rounded,
                size: AppTokens.checkIconSize,
              ),
              label: const Text('Open Settings'),
              style: TextButton.styleFrom(foregroundColor: AppTokens.ice200),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyResultSheet extends ConsumerStatefulWidget {
  final ExtractedTransaction detectedTransaction;

  const _VerifyResultSheet({required this.detectedTransaction});

  @override
  ConsumerState<_VerifyResultSheet> createState() => _VerifyResultSheetState();
}

class _VerifyResultSheetState extends ConsumerState<_VerifyResultSheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentProvider);
    final isLoading = state.status == PaymentVerifyStatus.loading;

    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    if (isLoading) {
      // Keep the loading state on the app's accent color (brightGreen) to
      // match the spinner and the rest of the app's active states.
      statusColor = AppTokens.accent;
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Verifying Transaction...';
      statusSubtitle = 'Checking with payment provider...';
    } else if (state.status == PaymentVerifyStatus.error) {
      statusColor = AppTokens.warning;
      statusIcon = Icons.cloud_off_rounded;
      statusTitle = 'Verification Unavailable';
      statusSubtitle =
          state.errorMessage ??
          'Verification service is temporarily unavailable. Please try again in a few minutes.';
    } else if (state.result != null) {
      switch (state.result!.status) {
        case VerificationStatus.verified:
          statusColor = AppTokens.accent;
          statusIcon = Icons.check_circle_rounded;
          statusTitle = 'Verified ✅';
          statusSubtitle = state.result!.message.isNotEmpty
              ? state.result!.message
              : 'Payment confirmed';
          break;
        case VerificationStatus.alreadyVerified:
        case VerificationStatus.previouslyVerified:
          statusColor = AppTokens.accent;
          statusIcon = Icons.verified_rounded;
          statusTitle = 'Previously Verified';
          statusSubtitle = state.result!.message.isNotEmpty
              ? state.result!.message
              : 'This receipt was already verified for your business. No new record was created.';
          break;
        case VerificationStatus.providerDuplicate:
          statusColor = AppTokens.warning;
          statusIcon = Icons.warning_amber_rounded;
          statusTitle = 'Provider Duplicate';
          statusSubtitle = state.result!.message.isNotEmpty
              ? state.result!.message
              : 'The provider recognizes this receipt, but no matching payment record exists for your business.';
          break;
        case VerificationStatus.identityMismatch:
          statusColor = AppTokens.error;
          statusIcon = Icons.cancel_rounded;
          statusTitle = 'Details Do Not Match';
          statusSubtitle = state.result!.message.isNotEmpty
              ? state.result!.message
              : 'The submitted details differ from the original verified payment.';
          break;
        case VerificationStatus.recheckFailed:
          statusColor = AppTokens.warning;
          statusIcon = Icons.cloud_off_rounded;
          statusTitle = 'Recheck Inconclusive';
          statusSubtitle = state.result!.message.isNotEmpty
              ? state.result!.message
              : 'The previous payment could not be re-confirmed. Please try again.';
          break;
        case VerificationStatus.needsReview:
          statusColor = AppTokens.warning;
          statusIcon = Icons.rate_review_rounded;
          statusTitle = 'Needs Review';
          statusSubtitle = state.result!.message.isNotEmpty
              ? state.result!.message
              : 'This receipt needs manual review. Contact support with your receipt.';
          break;
        case VerificationStatus.failed:
          statusColor = AppTokens.error;
          statusIcon = Icons.cancel_rounded;
          statusTitle = 'Verification Failed';
          statusSubtitle =
              state.result!.message ??
              'Unable to verify payment. Please check the details and try again.';
          break;
        case VerificationStatus.providerUnavailable:
          statusColor = AppTokens.warning;
          statusIcon = Icons.cloud_off_rounded;
          statusTitle = 'Provider Unavailable';
          statusSubtitle =
              state.result!.message ??
              'Verification service is temporarily unavailable. Please try again in a few minutes.';
          break;
        case VerificationStatus.quotaExhausted:
          statusColor = AppTokens.warning;
          statusIcon = Icons.report_problem_rounded;
          statusTitle = 'Verification Quota Exhausted';
          statusSubtitle =
              state.result!.message ??
              'Verification quota exhausted. Please contact your administrator.';
          break;
        case VerificationStatus.providerConfigError:
          statusColor = AppTokens.warning;
          statusIcon = Icons.settings_suggest_rounded;
          statusTitle = 'Verification Misconfigured';
          statusSubtitle =
              state.result!.message ??
              'Payment verification is temporarily misconfigured. Please contact your administrator.';
          break;
        case VerificationStatus.paymentAccountNotConfigured:
          statusColor = AppTokens.warning;
          statusIcon = Icons.account_balance_wallet_outlined;
          statusTitle = 'Payment Account Not Configured';
          statusSubtitle =
              state.result!.message ??
              'No receiving account is configured for this payment provider. Add it in settings, or verify against your registered bank account.';
          break;
        case VerificationStatus.providerUndetected:
          statusColor = AppTokens.warning;
          statusIcon = Icons.help_outline_rounded;
          statusTitle = 'Provider Not Detected';
          statusSubtitle =
              state.result!.message ??
              'Could not determine the payment provider from this receipt. Please select the provider and try again.';
          break;
        case VerificationStatus.unsupportedProvider:
          statusColor = AppTokens.warning;
          statusIcon = Icons.block_rounded;
          statusTitle = 'Unsupported Provider';
          statusSubtitle =
              state.result!.message ??
              'The selected payment provider is not supported.';
          break;
        case VerificationStatus.pending:
          // Unknown/unrecognized backend verdicts land here too — they must
          // never be presented as a definitive "Invalid Transaction".
          statusColor = AppTokens.info;
          statusIcon = Icons.hourglass_top_rounded;
          statusTitle = 'Pending Verification';
          statusSubtitle =
              state.result!.message ??
              'Verification result could not be determined. Please check the history tab.';
          break;
      }
    } else {
      statusColor = AppTokens.textSecondary;
      statusIcon = Icons.info_rounded;
      statusTitle = 'No Result';
      statusSubtitle = '';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTokens.headerBase,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusField),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTokens.sheetHorizontalPadding,
        AppTokens.spaceLg,
        AppTokens.sheetHorizontalPadding,
        AppTokens.space2xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppTokens.logoIconSize,
            height: AppTokens.handleHeight,
            decoration: BoxDecoration(
              color: AppTokens.inkMuted,
              borderRadius: BorderRadius.circular(AppTokens.progressStroke),
            ),
          ),
          const SizedBox(height: AppTokens.space2xl + AppTokens.spaceXs),

          if (isLoading)
            const SvLoader.large()
          else
            Container(
              width: AppTokens.patternTileWidth,
              height: AppTokens.patternTileWidth,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: AppTokens.alphaLow),
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor.withValues(alpha: AppTokens.alphaStrong),
                  width: AppTokens.progressStroke,
                ),
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: AppTokens.handleWidth,
              ),
            ),

          const SizedBox(height: AppTokens.spaceLg),
          Text(
            statusTitle,
            style: AppTokens.manrope(
              size: AppTokens.textSubtitle,
              weight: FontWeight.w800,
              color: statusColor,
            ),
          ),
          if (statusSubtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.titleLanguageGap),
              child: Text(
                statusSubtitle,
                style: AppTokens.dmSans(
                  size: AppTokens.textLabel,
                  weight: FontWeight.w400,
                  color: AppTokens.white.withValues(
                    alpha: AppTokens.alphaSecondary,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (state.result != null &&
              (state.result!.transactionId.isNotEmpty ||
                  state.result!.paymentDate != null ||
                  state.result!.verifiedAt != null))
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.spaceXl),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTokens.spaceLg),
                decoration: BoxDecoration(
                  color: AppTokens.obsidian950,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: AppTokens.obsidian700,
                    width: AppTokens.componentBorderWidth,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      label: 'Reference',
                      value:
                          state.result!.reference ??
                          state.result!.transactionId,
                    ),
                    if (state.result!.amount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                        child: _DetailRow(
                          label: 'Verified Amount',
                          value:
                              '${state.result!.currency} ${state.result!.amount.toStringAsFixed(2)}',
                          valueColor: AppTokens.accent,
                        ),
                      ),
                    if (state.result!.paymentDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                        child: _DetailRow(
                          label: 'Payment Date',
                          value: DateFormat(
                            'MMM d, yyyy · HH:mm',
                          ).format(state.result!.paymentDate!.toLocal()),
                        ),
                      ),
                    if (state.result!.verifiedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                        child: _DetailRow(
                          label: 'Verified On',
                          value: DateFormat(
                            'MMM d, yyyy · HH:mm',
                          ).format(state.result!.verifiedAt!.toLocal()),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: AppTokens.spaceXl),

          if (!isLoading)
            SizedBox(
              width: double.infinity,
              height: AppTokens.buttonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.accent,
                  foregroundColor: AppTokens.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  elevation: AppTokens.cardElevation,
                ),
                child: Text(
                  'Scan Again',
                  style: AppTokens.manrope(
                    size: AppTokens.buttonTextSize,
                    weight: FontWeight.w700,
                    color: AppTokens.ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTokens.dmSans(
            size: AppTokens.textLabel,
            weight: FontWeight.w400,
            color: AppTokens.white.withValues(alpha: AppTokens.alphaOverlay),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.manrope(
              size: AppTokens.textLabel,
              weight: FontWeight.w600,
              color: valueColor ?? AppTokens.white,
            ),
          ),
        ),
      ],
    );
  }
}
