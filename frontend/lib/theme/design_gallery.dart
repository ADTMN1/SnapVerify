import 'package:flutter/material.dart';
import 'app_text.dart';
import 'app_tokens.dart';

class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SnapVerify Design Gallery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space2xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Colors', style: AppText.onDark(AppText.titleLarge)),
            const SizedBox(height: AppTokens.spaceLg),
            Wrap(
              spacing: AppTokens.spaceMd,
              runSpacing: AppTokens.spaceMd,
              children: [
                _swatch('Ink', AppTokens.ink),
                _swatch('Ink muted', AppTokens.inkMuted),
                _swatch('Ice', AppTokens.ice50),
                _swatch('Ice muted', AppTokens.ice400),
                _swatch('Primary', AppTokens.primary),
                _swatch('Accent', AppTokens.accent),
                _swatch('Teal', AppTokens.teal),
                _swatch('Orange', AppTokens.orange),
                _swatch('Purple', AppTokens.purple),
                _swatch('Error', AppTokens.error),
                _swatch('Surface', AppTokens.surfaceDark),
                _swatch('Border', AppTokens.border),
              ],
            ),
            const SizedBox(height: AppTokens.space3xl),
            Text('Typography', style: AppText.onDark(AppText.titleLarge)),
            const SizedBox(height: AppTokens.spaceLg),
            Text(
              'Display • SnapVerify',
              style: AppText.onDark(AppText.displayLarge),
            ),
            Text(
              'Headline • Payment verification',
              style: AppText.onDark(AppText.headlineLarge),
            ),
            Text(
              'Title • Business switcher',
              style: AppText.onDark(AppText.titleMedium),
            ),
            Text(
              'Body • Receipt details and status',
              style: AppText.onDark(AppText.bodyMedium),
            ),
            Text(
              'Caption • Updated just now',
              style: AppText.onDark(AppText.caption),
            ),
            const SizedBox(height: AppTokens.space3xl),
            Text('Radii', style: AppText.onDark(AppText.titleLarge)),
            const SizedBox(height: AppTokens.spaceLg),
            Wrap(
              spacing: AppTokens.spaceMd,
              runSpacing: AppTokens.spaceMd,
              children: [
                _radiusPreview('Field', AppTokens.fieldBorderRadius),
                _radiusPreview('Button', AppTokens.buttonBorderRadius),
                _radiusPreview('Card', AppTokens.cardBorderRadius),
                _radiusPreview('Toggle', AppTokens.toggleBorderRadius),
                _radiusPreview('Sheet', AppTokens.sheetBorderRadius),
              ],
            ),
            const SizedBox(height: AppTokens.space3xl),
            Text('Components', style: AppText.onDark(AppText.titleLarge)),
            const SizedBox(height: AppTokens.spaceLg),
            FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                textStyle: AppText.authButton,
                foregroundColor: AppTokens.ink,
                backgroundColor: AppTokens.accent,
                minimumSize: const Size(double.infinity, AppTokens.buttonHeight),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppTokens.buttonBorderRadius,
                ),
              ),
              child: const Text('Primary action'),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Secondary action'),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Reference number',
                hintText: 'FT123456789',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(String label, Color color) {
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.light
        ? AppTokens.ink
        : AppTokens.white;
    return SizedBox(
      width: AppTokens.logoTileSize,
      height: AppTokens.logoTileSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: AppTokens.cardBorderRadius,
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.labelSmall.copyWith(color: onColor),
          ),
        ),
      ),
    );
  }

  Widget _radiusPreview(String label, BorderRadius borderRadius) {
    return SizedBox(
      width: AppTokens.logoTileSize * 2,
      height: AppTokens.logoTileSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTokens.surfaceDark,
          borderRadius: borderRadius,
          border: Border.all(color: AppTokens.obsidian700),
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.onDark(AppText.labelSmall),
          ),
        ),
      ),
    );
  }
}
