import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class SVCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool hasShadow;
  final double borderRadius;
  final Color? backgroundColor;

  const SVCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.space2xl),
    this.margin,
    this.onTap,
    this.hasShadow = true,
    this.borderRadius = AppTokens.radius2xl,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTokens.obsidian800,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasShadow ? const [AppTokens.cardShadow] : null,
      ),
      child: onTap != null
          ? Material(
              color: AppTokens.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(borderRadius),
                onTap: onTap,
                child: Padding(padding: padding!, child: child),
              ),
            )
          : Padding(padding: padding!, child: child),
    );
  }
}

class SVStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final String? change;
  final bool isPositive;
  final VoidCallback? onTap;

  const SVStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppTokens.accent,
    this.backgroundColor,
    this.change,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final changeColor = isPositive ? AppTokens.success : AppTokens.error;
    return SVCard(
      onTap: onTap,
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.all(AppTokens.statCardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppTokens.statTileSize,
                height: AppTokens.statTileSize,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: AppTokens.alphaMedium),
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: AppTokens.statIconSize,
                ),
              ),
              if (change != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.statChangePaddingH,
                    vertical: AppTokens.statChangePaddingV,
                  ),
                  decoration: BoxDecoration(
                    color: changeColor.withValues(alpha: AppTokens.alphaMedium),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: AppTokens.statChangeIconSize,
                        color: changeColor,
                      ),
                      const SizedBox(width: AppTokens.spaceXs),
                      Text(
                        change!,
                        style: AppTokens.dmSans(
                          size: AppTokens.statChangeFontSize,
                          weight: FontWeight.w600,
                          color: changeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppTokens.statGap),
          Text(
            title,
            style: AppTokens.dmSans(
              size: AppTokens.statTitleSize,
              weight: FontWeight.w500,
              color: AppTokens.white.withValues(
                alpha: AppTokens.alphaPrimaryMuted,
              ),
            ),
          ),
          const SizedBox(height: AppTokens.statTitleGap),
          Text(
            value,
            style: AppTokens.manrope(
              size: AppTokens.statValueSize,
              weight: FontWeight.w700,
              color: AppTokens.white,
            ),
          ),
        ],
      ),
    );
  }
}
