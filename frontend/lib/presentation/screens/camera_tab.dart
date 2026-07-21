
import 'dart:developer' as dev;
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/tailwind.dart';
import '../../core/utils/ocr_parser.dart';
import '../../domain/entities/verification_result.dart';
import '../providers/payment_provider.dart';

class CameraTab extends ConsumerStatefulWidget {
  const CameraTab({super.key});

  @override
  ConsumerState<CameraTab> createState() => _CameraTabState();
}

class _CameraTabState extends ConsumerState<CameraTab> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  bool _torchOn = false;
  String? _initError;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    dev.log('[CameraTab] Initializing camera...');
    try {
      dev.log('[CameraTab] Requesting camera permission...');
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        dev.log('[CameraTab] Camera permission denied!');
        if (mounted) setState(() => _initError = 'Camera permission is required');
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        dev.log('[CameraTab] No cameras found');
        if (mounted) setState(() => _initError = 'No camera found on this device');
        return;
      }

      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      dev.log('[CameraTab] Using camera: ${back.name}');

      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await ctrl.initialize();
      dev.log('[CameraTab] Camera initialized successfully');

      if (!mounted) return;
      _controller = ctrl;
      setState(() {
        _initialized = true;
        _initError = null;
      });
    } catch (e, stackTrace) {
      dev.log('[CameraTab] Camera initialization error: $e');
      dev.log('[CameraTab] Stack trace: $stackTrace');
      if (mounted) setState(() => _initError = 'Camera error: $e');
    }
  }

  Future<void> _captureAndProcess() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    try {
      dev.log('[CameraTab] Capturing image...');
      final XFile imageFile = await ctrl.takePicture();
      dev.log('[CameraTab] Image captured: ${imageFile.path}');

      final inputImage = InputImage.fromFilePath(imageFile.path);
      dev.log('[CameraTab] Starting OCR processing...');
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final ocrText = recognizedText.text;
      dev.log('[CameraTab] OCR complete. Text length: ${ocrText.length}');
      if (ocrText.isNotEmpty) {
        dev.log('[CameraTab] OCR Text: $ocrText');
      }

      final transaction = OcrParser.extractTransaction(recognizedText);
    dev.log('[CameraTab] Extracted transaction: ref=${transaction?.referenceId}, suffix=${transaction?.suffix}, amount=${transaction?.amount}, provider=${transaction?.provider}');

    if (transaction != null && mounted) {
      dev.log('[CameraTab] Verifying transaction...');
      ref.read(paymentProvider.notifier).reset();
      ref.read(paymentProvider.notifier).verifyReference(
            transaction.referenceId,
            amount: transaction.amount,
            provider: transaction.provider,
            suffix: transaction.suffix,
          );
      _showResultSheet(transaction);
    } else if (mounted) {
      // Show professional error for invalid image
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Receipt'),
          content: const Text(
            'We couldn\'t find a valid transaction in the captured image. '
            'Please make sure the receipt is clear and contains a transaction reference number.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  } catch (e, stackTrace) {
      dev.log('[CameraTab] Error capturing/processing image: $e');
      dev.log('[CameraTab] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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
          ? _ErrorView(message: _initError!, onRetry: _initCamera)
          : !_initialized
              ? const Center(child: CircularProgressIndicator(color: TwColors.brightGreen))
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
            onTap: _captureAndProcess,
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

        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [TwColors.brightGreen, TwColors.lime400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.verified_rounded, color: Colors.black, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SnapVerify',
                            style: TextStyle(color: TwColors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Capture receipt to verify',
                            style: TextStyle(color: TwColors.slate400, fontSize: 12),
                          ),
                        ],
                      ),
                    ]),
                    GestureDetector(
                      onTap: () async {
                        await ctrl.setFlashMode(_torchOn ? FlashMode.off : FlashMode.torch);
                        setState(() => _torchOn = !_torchOn);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _torchOn ? TwColors.brightGreen.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _torchOn ? TwColors.brightGreen.withOpacity(0.5) : Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                          color: _torchOn ? TwColors.brightGreen : TwColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                child: GestureDetector(
                  onTap: _captureAndProcess,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: TwColors.brightGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: TwColors.lime400, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.black, size: 30),
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

  const _ErrorView({required this.message, required this.onRetry});

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
              child: const Icon(Icons.no_photography_rounded, color: TwColors.red500, size: 40),
            ),
            const SizedBox(height: 20),
            Text(message,
                style: TextStyle(color: TwColors.white.withOpacity(0.7), fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: TwColors.brightGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
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
      statusColor = TwColors.sky500;
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Verifying Transaction...';
      statusSubtitle = 'Checking with payment provider...';
    } else if (state.status == PaymentVerifyStatus.error) {
      statusColor = TwColors.red500;
      statusIcon = Icons.error_outline_rounded;
      statusTitle = 'Verification Failed';
      statusSubtitle = state.errorMessage ?? 'Unable to verify payment. Please check the details and try again.';
    } else if (state.result != null) {
      switch (state.result!.status) {
        case VerificationStatus.verified:
          statusColor = TwColors.brightGreen;
          statusIcon = Icons.check_circle_rounded;
          statusTitle = 'Verified ✅';
          statusSubtitle = state.result!.message.isNotEmpty ? state.result!.message : 'Payment confirmed';
          break;
        case VerificationStatus.alreadyVerified:
          statusColor = Colors.orange;
          statusIcon = Icons.warning_amber_rounded;
          statusTitle = 'Already Used';
          statusSubtitle = state.result!.message ?? 'This payment has already been verified';
          break;
        default:
          statusColor = TwColors.red500;
          statusIcon = Icons.cancel_rounded;
          statusTitle = 'Invalid Transaction';
          statusSubtitle = state.result!.message ?? 'Unable to verify payment. Please check the details and try again.';
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
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: TwColors.slate600, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 28),

          if (isLoading)
            const Column(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(color: TwColors.brightGreen, strokeWidth: 3),
                ),
              ],
            )
          else
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor.withOpacity(0.35), width: 2),
              ),
              child: Icon(statusIcon, color: statusColor, size: 36),
            ),

          const SizedBox(height: 16),
          Text(statusTitle, style: TextStyle(color: statusColor, fontSize: 20, fontWeight: FontWeight.w800)),
          if (statusSubtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(statusSubtitle,
                  style: TextStyle(color: TwColors.white.withOpacity(0.55), fontSize: 13),
                  textAlign: TextAlign.center),
            ),

          if (state.result != null && state.result!.transactionId.isNotEmpty)
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
                          value: '${state.result!.currency} ${state.result!.amount.toStringAsFixed(2)}',
                          valueColor: TwColors.brightGreen,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Scan Again', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
        Text(label,
            style: TextStyle(color: TwColors.white.withOpacity(0.45), fontSize: 13)),
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

