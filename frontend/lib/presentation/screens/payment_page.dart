import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/tailwind.dart';
import '../../domain/entities/subscription_checkout.dart';
import '../providers/subscription_provider.dart';
import '../widgets/sv_loader.dart';

class PaymentPage extends ConsumerStatefulWidget {
  const PaymentPage({super.key});

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  XFile? _screenshot;
  Uint8List? _screenshotBytes;
  String? _ocrText;

  @override
  Widget build(BuildContext context) {
    final checkoutState = ref.watch(subscriptionCheckoutProvider);
    final checkout = checkoutState.checkout;

    return Scaffold(
      backgroundColor: TwColors.primaryBg,
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: TwColors.primaryBg,
        foregroundColor: TwColors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(color: TwColors.slate700),
        ),
      ),
      body: checkout == null
          ? const Center(
              child: Text(
                'No payment selected',
                style: TextStyle(color: TwColors.slate400),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PaymentCard(checkout: checkout),
                    const SizedBox(height: 16),
                    const Text(
                      'Pay the amount above to the account shown, then upload a screenshot of the receipt.',
                      style: TextStyle(
                        color: TwColors.slate400,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: checkoutState.isLoading ? null : _pickScreenshot,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: TwColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TwColors.slate700),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              color: TwColors.slate400,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _screenshot == null
                                        ? 'Upload screenshot'
                                        : 'Screenshot selected',
                                    style: const TextStyle(
                                      color: TwColors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _screenshot == null
                                        ? 'Choose the payment receipt from your gallery'
                                        : _screenshot!.name,
                                    style: const TextStyle(
                                      color: TwColors.slate400,
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.upload_file,
                              color: TwColors.slate400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (checkoutState.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        checkoutState.error!,
                        style: const TextStyle(
                          color: TwColors.red400,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            checkoutState.isLoading || _screenshotBytes == null
                            ? null
                            : _verify,
                        style: FilledButton.styleFrom(
                          backgroundColor: TwColors.brightGreen,
                          foregroundColor: TwColors.slate900,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: checkoutState.isLoading
                            ? const SvLoader.button()
                            : const Text(
                                'Verify & activate',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _pickScreenshot() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final recognizer = TextRecognizer();
      String text;
      try {
        final recognized = await recognizer.processImage(
          InputImage.fromFilePath(file.path),
        );
        text = recognized.text;
      } finally {
        await recognizer.close();
      }

      if (!mounted) return;
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read the receipt. Please choose a clearer screenshot.',
            ),
          ),
        );
        return;
      }

      setState(() {
        _screenshot = file;
        _screenshotBytes = bytes;
        _ocrText = text;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read the screenshot: $e')),
      );
    }
  }

  Future<void> _verify() async {
    final bytes = _screenshotBytes;
    if (bytes == null) return;

    final active = await ref
        .read(subscriptionCheckoutProvider.notifier)
        .verifyWithScreenshot(
          bytes,
          mimeType: _screenshot?.mimeType ?? 'image/jpeg',
          ocrText: _ocrText,
        );
    if (!mounted || !active) return;
    ref.read(subscriptionCheckoutProvider.notifier).reset();
    Navigator.of(context).pop(true);
  }
}

class _PaymentCard extends StatelessWidget {
  final SubscriptionCheckout checkout;

  const _PaymentCard({required this.checkout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TwColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TwColors.slate700),
      ),
      child: Column(
        children: [
          _PaymentRow(label: 'Plan', value: _labelForPlan(checkout.planName)),
          const SizedBox(height: 12),
          _PaymentRow(
            label: 'Amount',
            value: '${checkout.amount} ${checkout.currency}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: TwColors.slate700, height: 1),
          ),
          _PaymentRow(
            label: 'Telebirr account',
            value: checkout.payToAccountNumber,
          ),
          if (checkout.payToAccountName != null) ...[
            const SizedBox(height: 12),
            _PaymentRow(
              label: 'Account name',
              value: checkout.payToAccountName!,
            ),
          ],
        ],
      ),
    );
  }

  String _labelForPlan(String planName) {
    switch (planName.toLowerCase()) {
      case 'free':
      case 'free_trial':
        return 'Free';
      case 'one_month':
        return '1 Month';
      case 'three_months':
        return '3 Months';
      case 'six_months':
        return '6 Months';
      case 'one_year':
        return '1 Year';
      default:
        return planName
            .split(RegExp(r'[_\s]+'))
            .map(
              (word) => word.isEmpty
                  ? word
                  : word[0].toUpperCase() + word.substring(1).toLowerCase(),
            )
            .join(' ');
    }
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;

  const _PaymentRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: TwColors.slate400, fontSize: 12.5),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
