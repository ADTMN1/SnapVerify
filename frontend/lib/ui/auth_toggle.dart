import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

class AuthToggleItem {
  const AuthToggleItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

class AuthSegmentedToggle extends StatelessWidget {
  const AuthSegmentedToggle({super.key, required this.items});

  final List<AuthToggleItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.togglePadding),
      decoration: BoxDecoration(
        color: AppTokens.ice100,
        borderRadius: BorderRadius.circular(AppTokens.toggleContainerRadius),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Semantics(
                selected: item.selected,
                button: true,
                child: GestureDetector(
                  onTap: item.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: AppTokens.motionFast),
                    curve: AppTokens.curveStandard,
                    height: AppTokens.toggleButtonHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.selected
                          ? AppTokens.obsidian950
                          : AppTokens.transparent,
                      borderRadius: BorderRadius.circular(
                        AppTokens.toggleButtonRadius,
                      ),
                    ),
                    child: Text(
                      item.label,
                      style: item.selected
                          ? AppText.authToggleSelected
                          : AppText.authToggleUnselected,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
