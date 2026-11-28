import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/language_provider.dart';
import '../../theme/app_text.dart';
import '../../theme/app_tokens.dart';
import '../widgets/sv_app_shell.dart';

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
      backgroundColor: AppTokens.ice50,
      body: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Column(
          children: [
            SvDashboardHeader(
              title: 'Language',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppTokens.formMaxWidth,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space2xl,
                      AppTokens.spaceXl,
                      AppTokens.space2xl,
                      AppTokens.space3xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SvSurfaceCard(
                          padding: EdgeInsets.zero,
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
                        const SizedBox(height: AppTokens.space2xl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceLg,
        ),
        decoration: BoxDecoration(
          color: selected ? AppTokens.ice100 : AppTokens.white,
          border: Border(
            bottom: BorderSide(
              color: AppTokens.ice200,
              width: AppTokens.componentBorderWidth,
            ),
            left: BorderSide(
              color: selected ? AppTokens.ice200 : AppTokens.transparent,
              width: AppTokens.componentBorderWidthStrong * 2,
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
                color: selected ? AppTokens.ice200 : AppTokens.surfaceLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                border: Border.all(
                  color: selected ? AppTokens.inkMuted : AppTokens.ice200,
                  width: AppTokens.componentBorderWidth,
                ),
              ),
              child: Text(
                language.shortName,
                style: AppText.labelSmall.copyWith(
                  color: selected ? AppTokens.ink : AppTokens.inkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.heroStatusPaddingH),
            Expanded(
              child: Text(
                language.displayName,
                style: AppText.labelLarge.copyWith(
                  color: AppTokens.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTokens.ink,
                size: AppTokens.componentIconMd,
              ),
          ],
        ),
      ),
    );
  }
}
