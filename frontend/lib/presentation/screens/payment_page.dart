import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/subscription_checkout.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
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
      backgroundColor: AppTokens.headerBase,
      appBar: AppBar(
        title: Text('Payment', style: AppText.headlineMedium),
        centerTitle: true,
        backgroundColor: AppTokens.headerBase,
        foregroundColor: AppTokens.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(AppTokens.dividerHeight),
          child: ColoredBox(color: AppTokens.obsidian700),
        ),
      ),
      body: checkout == null
          ? Center(
              child: Text(
                'No payment selected',
                style: AppTokens.dmSans(
                  size: AppTokens.textBodySmall,
                  weight: FontWeight.w400,
                  color: AppTokens.ice400,
                ),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.spaceXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PaymentCard(checkout: checkout),
                    const SizedBox(height: AppTokens.spaceLg),
                    Text(
                      'Pay the amount above to the account shown, then upload a screenshot of the receipt.',
                      style: AppTokens.dmSans(
                        size: AppTokens.textCaption,
                        weight: FontWeight.w400,
                        color: AppTokens.ice400,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceMd),
                    InkWell(
                      onTap: checkoutState.isLoading ? null : _pickScreenshot,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceLg,
                          vertical: AppTokens.inputPaddingH,
                        ),
                        decoration: BoxDecoration(
                          color: AppTokens.headerFacetA,
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                          border: Border.all(color: AppTokens.obsidian700),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              color: AppTokens.ice400,
                            ),
                            const SizedBox(width: AppTokens.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _screenshot == null
                                        ? 'Upload screenshot'
                                        : 'Screenshot selected',
                                    style: AppTokens.manrope(
                                      size: AppTokens.textLabel,
                                      weight: FontWeight.w600,
                                      color: AppTokens.white,
                                    ),
                                  ),
                                  const SizedBox(height: AppTokens.spaceXs),
                                  Text(
                                    _screenshot == null
                                        ? 'Choose the payment receipt from your gallery'
                                        : _screenshot!.name,
                                    style: AppTokens.dmSans(
                                      size: AppTokens.textOverline,
                                      weight: FontWeight.w400,
                                      color: AppTokens.ice400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.upload_file,
                              color: AppTokens.ice400,
                              size: AppTokens.componentIconMd,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (checkoutState.error != null) ...[
                      const SizedBox(height: AppTokens.spaceMd),
                      Text(
                        checkoutState.error!,
                        style: AppTokens.dmSans(
                          size: AppTokens.textLabel,
                          weight: FontWeight.w400,
                          color: AppTokens.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.spaceXl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            checkoutState.isLoading || _screenshotBytes == null
                            ? null
                            : _verify,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTokens.accent,
                          foregroundColor: AppTokens.obsidian950,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.spaceLg,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTokens.cardBorderRadius,
                          ),
                        ),
                        child: checkoutState.isLoading
                            ? const SvLoader.button()
                            : Text('Verify & activate', style: AppText.button),
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
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      decoration: BoxDecoration(
        color: AppTokens.headerFacetA,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppTokens.obsidian700),
      ),
      child: Column(
        children: [
          _PaymentRow(label: 'Plan', value: _labelForPlan(checkout.planName)),
          const SizedBox(height: AppTokens.spaceMd),
          _PaymentRow(
            label: 'Amount',
            value: '${checkout.amount} ${checkout.currency}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTokens.badgePaddingH),
            child: Divider(
              color: AppTokens.obsidian700,
              height: AppTokens.dividerHeight,
            ),
          ),
          _PaymentRow(
            label: 'Telebirr account',
            value: checkout.payToAccountNumber,
          ),
          if (checkout.payToAccountName != null) ...[
            const SizedBox(height: AppTokens.spaceMd),
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
          style: AppTokens.dmSans(
            size: AppTokens.textCaption,
            weight: FontWeight.w400,
            color: AppTokens.ice400,
          ),
        ),
        const SizedBox(width: AppTokens.spaceLg),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTokens.manrope(
              size: AppTokens.textCaption,
              weight: FontWeight.w600,
              color: AppTokens.white,
            ),
          ),
        ),
      ],
    );
  }
}
