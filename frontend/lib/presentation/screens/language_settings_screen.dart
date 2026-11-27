import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language_provider.dart';
import '../../theme/app_tokens.dart';

/// Lets the user pick the UI language.
///
/// The choice is applied immediately through [languageProvider], which also
/// persists it per device and per authenticated user.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppTokens.headerBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.spaceLg,
                  AppTokens.spaceXl,
                  AppTokens.spaceLg,
                  AppTokens.space3xl,
                ),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTokens.obsidian950,
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      border: Border.all(
                        color: AppTokens.obsidian700,
                        width: AppTokens.componentBorderWidth,
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final language in AppLanguage.values)
                          _LanguageTile(
                            language: language,
                            selected: language == selected,
                            onTap: () => ref
                                .read(languageProvider.notifier)
                                .select(language),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceLg,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTokens.obsidian800,
            width: AppTokens.componentBorderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: AppTokens.handleWidth,
              height: AppTokens.handleWidth,
              decoration: BoxDecoration(
                color: AppTokens.obsidian800,
                borderRadius: BorderRadius.circular(AppTokens.backButtonRadius),
                border: Border.all(
                  color: AppTokens.obsidian700,
                  width: AppTokens.componentBorderWidth,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTokens.white,
                size: AppTokens.progressSize,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.spaceLg),
          Expanded(
            child: Text(
              'Language',
              style: AppTokens.manrope(
                size: AppTokens.textSubtitle,
                weight: FontWeight.w700,
                color: AppTokens.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppTokens.accent : AppTokens.ice400;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceLg,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTokens.obsidian800,
              width: AppTokens.componentBorderWidth,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: AppTokens.handleWidth,
              height: AppTokens.handleWidth,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: AppTokens.alphaLow),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Text(
                language.shortName,
                style: AppTokens.manrope(
                  size: AppTokens.textCaption,
                  weight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.heroStatusPaddingH),
            Expanded(
              child: Text(
                language.displayName,
                style: AppTokens.manrope(
                  size: AppTokens.textBody,
                  weight: FontWeight.w600,
                  color: AppTokens.white,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTokens.accent,
                size: AppTokens.componentIconMd,
              ),
          ],
        ),
      ),
    );
  }
}
