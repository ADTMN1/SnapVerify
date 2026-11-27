import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

class AuthLanguageItem {
  const AuthLanguageItem({
    required this.shortName,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String shortName;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class AuthLanguagePill extends StatelessWidget {
  const AuthLanguagePill({super.key, required this.items});

  final List<AuthLanguageItem> items;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Language',
      child: Container(
        padding: const EdgeInsets.all(AppTokens.languagePillPadding),
        decoration: BoxDecoration(
          color: AppTokens.ice100,
          borderRadius: BorderRadius.circular(AppTokens.languagePillRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              Semantics(
                button: true,
                selected: item.selected,
                label: item.label,
                child: GestureDetector(
                  onTap: item.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: AppTokens.motionFast),
                    curve: AppTokens.curveStandard,
                    height: AppTokens.languageItemHeight,
                    constraints: const BoxConstraints(
                      minWidth: AppTokens.languageItemMinWidth,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.languageItemPaddingH,
                    ),
                    decoration: BoxDecoration(
                      color: item.selected
                          ? AppTokens.obsidian950
                          : AppTokens.transparent,
                      borderRadius: BorderRadius.circular(
                        AppTokens.languageItemRadius,
                      ),
                    ),
                    child: Text(
                      item.shortName,
                      style: item.selected
                          ? AppText.authLanguageSelected
                          : AppText.authLanguageUnselected,
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
