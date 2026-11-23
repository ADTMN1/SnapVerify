import 'package:flutter/foundation.dart';

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/tailwind.dart';
import '../../core/utils/ocr_parser.dart';
import '../../core/utils/toast_service.dart';
import '../../domain/entities/verification_result.dart';
import '../../domain/entities/payment_account.dart';
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
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: TwColors.primaryBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TwColors.slate600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Payment Provider',
                style: TextStyle(
                  color: TwColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We could not confidently detect the provider from this receipt. '
                'Choose the provider shown on the receipt.',
                style: TextStyle(
                  color: TwColors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ...PaymentProvider.values.map(
                (provider) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(sheetContext).pop(provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: TwColors.slate700,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_rounded,
                              color: TwColors.brightGreen,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                provider.label,
                                style: TextStyle(
                                  color: TwColors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: TwColors.slate500,
                              size: 22,
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
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: TwColors.slate700),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: TwColors.red500.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: TwColors.red500,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Invalid Receipt',
                style: TextStyle(
                  color: TwColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "We couldn't find a valid transaction in the captured image. "
                'Please make sure the receipt is clear and contains a '
                'transaction reference number.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TwColors.slate400,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TwColors.brightGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: TwColors.slate900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
      backgroundColor: Colors.transparent,
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
      backgroundColor: Colors.black,
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
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvLoader.page(),
                    SizedBox(height: 16),
                    Text(
                      'Reading receipt…',
                      style: TextStyle(color: TwColors.white, fontSize: 14),
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
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [TwColors.brightGreen, TwColors.lime400],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SnapVerify',
                              style: TextStyle(
                                color: TwColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Capture receipt to verify',
                              style: TextStyle(
                                color: TwColors.slate400,
                                fontSize: 13,
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _torchOn
                              ? TwColors.brightGreen.withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _torchOn
                                ? TwColors.brightGreen.withOpacity(0.5)
                                : Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _torchOn
                              ? Icons.flashlight_on_rounded
                              : Icons.flashlight_off_rounded,
                          color: _torchOn
                              ? TwColors.brightGreen
                              : TwColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 32,
                ),
                child: GestureDetector(
                  onTap: _processing ? null : _captureAndProcess,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _processing
                          ? TwColors.slate700
                          : TwColors.brightGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _processing
                            ? TwColors.slate600
                            : TwColors.lime400,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: _processing ? TwColors.slate400 : Colors.black,
                      size: 30,
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TwColors.red500.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: TwColors.red500.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.no_photography_rounded,
                color: TwColors.red500,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: TwColors.white.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: TwColors.brightGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('Open Settings'),
              style: TextButton.styleFrom(foregroundColor: TwColors.slate300),
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
      statusColor = TwColors.brightGreen;
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Verifying Transaction...';
      statusSubtitle = 'Checking with payment provider...';
    } else if (state.status == PaymentVerifyStatus.error) {
      statusColor = TwColors.amber500;
      statusIcon = Icons.cloud_off_rounded;
      statusTitle = 'Verification Unavailable';
      statusSubtitle =
          state.errorMessage ??
          'Verification service is temporarily unavailable. Please try again in a few minutes.';
    } else if (state.result != null) {
      switch (state.result!.status) {
        case VerificationStatus.verified:
          statusColor = TwColors.brightGreen;
          statusIcon = Icons.check_circle_rounded;
          statusTitle = 'Verified ✅';
          statusSubtitle = state.result!.message.isNotEmpty
              ? state.result!.message
              : 'Payment confirmed';
          break;
        case VerificationStatus.alreadyVerified:
          statusColor = TwColors.amber500;
          statusIcon = Icons.warning_amber_rounded;
          statusTitle = 'Already Used';
          statusSubtitle =
              state.result!.message ?? 'This payment has already been verified';
          break;
        case VerificationStatus.needsReview:
          statusColor = TwColors.amber500;
          statusIcon = Icons.rate_review_rounded;
          statusTitle = 'Needs Review';
          statusSubtitle = state.result!.message.isNotEmpty
              ? state.result!.message
              : 'This receipt needs manual review. Contact support with your receipt.';
          break;
        case VerificationStatus.failed:
          statusColor = TwColors.red500;
          statusIcon = Icons.cancel_rounded;
          statusTitle = 'Verification Failed';
          statusSubtitle =
              state.result!.message ??
              'Unable to verify payment. Please check the details and try again.';
          break;
        case VerificationStatus.providerUnavailable:
          statusColor = TwColors.amber500;
          statusIcon = Icons.cloud_off_rounded;
          statusTitle = 'Provider Unavailable';
          statusSubtitle =
              state.result!.message ??
              'Verification service is temporarily unavailable. Please try again in a few minutes.';
          break;
        case VerificationStatus.quotaExhausted:
          statusColor = TwColors.amber500;
          statusIcon = Icons.report_problem_rounded;
          statusTitle = 'Verification Quota Exhausted';
          statusSubtitle =
              state.result!.message ??
              'Verification quota exhausted. Please contact your administrator.';
          break;
        case VerificationStatus.providerConfigError:
          statusColor = TwColors.amber500;
          statusIcon = Icons.settings_suggest_rounded;
          statusTitle = 'Verification Misconfigured';
          statusSubtitle =
              state.result!.message ??
              'Payment verification is temporarily misconfigured. Please contact your administrator.';
          break;
        case VerificationStatus.paymentAccountNotConfigured:
          statusColor = TwColors.amber500;
          statusIcon = Icons.account_balance_wallet_outlined;
          statusTitle = 'Payment Account Not Configured';
          statusSubtitle =
              state.result!.message ??
              'No receiving account is configured for this payment provider. Add it in settings, or verify against your registered bank account.';
          break;
        case VerificationStatus.providerUndetected:
          statusColor = TwColors.amber500;
          statusIcon = Icons.help_outline_rounded;
          statusTitle = 'Provider Not Detected';
          statusSubtitle =
              state.result!.message ??
              'Could not determine the payment provider from this receipt. Please select the provider and try again.';
          break;
        case VerificationStatus.unsupportedProvider:
          statusColor = TwColors.amber500;
          statusIcon = Icons.block_rounded;
          statusTitle = 'Unsupported Provider';
          statusSubtitle =
              state.result!.message ??
              'The selected payment provider is not supported.';
          break;
        case VerificationStatus.pending:
          // Unknown/unrecognized backend verdicts land here too — they must
          // never be presented as a definitive "Invalid Transaction".
          statusColor = TwColors.sky500;
          statusIcon = Icons.hourglass_top_rounded;
          statusTitle = 'Pending Verification';
          statusSubtitle =
              state.result!.message ??
              'Verification result could not be determined. Please check the history tab.';
          break;
      }
    } else {
      statusColor = TwColors.slate500;
      statusIcon = Icons.info_rounded;
      statusTitle = 'No Result';
      statusSubtitle = '';
    }

    return Container(
      decoration: const BoxDecoration(
        color: TwColors.primaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: TwColors.slate600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          if (isLoading)
            const SvLoader.large()
          else
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor.withOpacity(0.35),
                  width: 2,
                ),
              ),
              child: Icon(statusIcon, color: statusColor, size: 36),
            ),

          const SizedBox(height: 16),
          Text(
            statusTitle,
            style: TextStyle(
              color: statusColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (statusSubtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                statusSubtitle,
                style: TextStyle(
                  color: TwColors.white.withOpacity(0.55),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (state.result != null &&
              (state.result!.transactionId.isNotEmpty ||
                  state.result!.paymentDate != null))
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TwColors.slate700, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      label: 'Transaction ID',
                      value: state.result!.transactionId,
                    ),
                    if (state.result!.amount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _DetailRow(
                          label: 'Verified Amount',
                          value:
                              '${state.result!.currency} ${state.result!.amount.toStringAsFixed(2)}',
                          valueColor: TwColors.brightGreen,
                        ),
                      ),
                    if (state.result!.paymentDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _DetailRow(
                          label: 'Payment Date',
                          value: DateFormat(
                            'MMM d, yyyy · HH:mm',
                          ).format(state.result!.paymentDate!.toLocal()),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          if (!isLoading)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TwColors.brightGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Scan Again',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
          style: TextStyle(
            color: TwColors.white.withOpacity(0.45),
            fontSize: 13,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? TwColors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
