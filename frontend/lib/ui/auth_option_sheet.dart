import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

class AuthOptionSheet<T extends Object> extends StatelessWidget {
  const AuthOptionSheet({
    super.key,
    required this.title,
    required this.options,
    required this.labelFor,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<T> options;
  final String Function(T option) labelFor;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.sheetHorizontalPadding,
        AppTokens.togglePadding,
        AppTokens.sheetHorizontalPadding,
        AppTokens.sheetBottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: AppTokens.handleWidth,
              height: AppTokens.handleHeight,
              decoration: BoxDecoration(
                color: AppTokens.ice200,
                borderRadius: BorderRadius.circular(AppTokens.handleHeight / 2),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.titleToggleGap),
          Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.authOptionTitle,
            ),
          ),
          const SizedBox(height: AppTokens.dropdownIconGap),
          Flexible(
            child: RadioGroup<T>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) onSelected(value);
              },
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (_, _) => Container(
                  height: AppTokens.dividerHeight,
                  color: AppTokens.ice100,
                ),
                itemBuilder: (_, index) {
                  final option = options[index];
                  final isSelected = option == selected;
                  return InkWell(
                    onTap: () => onSelected(option),
                    borderRadius: BorderRadius.circular(
                      AppTokens.toggleButtonRadius,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.optionPaddingH,
                        vertical: AppTokens.optionPaddingV,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTokens.ice100
                            : AppTokens.transparent,
                        borderRadius: BorderRadius.circular(
                          AppTokens.toggleButtonRadius,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              labelFor(option),
                              style: isSelected
                                  ? AppText.authOptionSelected
                                  : AppText.authOptionUnselected,
                            ),
                          ),
                          Radio<T>(
                            value: option,
                            fillColor: WidgetStateProperty.resolveWith<Color>((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return AppTokens.obsidian950;
                              }
                              return AppTokens.ice400;
                            }),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
