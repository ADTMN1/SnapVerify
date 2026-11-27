import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_header_pattern_painter.dart';
import 'app_logo_painter.dart';
import 'auth_back_button.dart';

class AuthTopBar extends StatelessWidget {
  const AuthTopBar({super.key, required this.onBack, this.trailing});

  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTokens.authTopBarHeight,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppTokens.radius2xl),
          bottomRight: Radius.circular(AppTokens.radius2xl),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: const AppHeaderPatternPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Positioned(
            top: AppTokens.authTopBarInset,
            left: AppTokens.authTopBarInset,
            right: AppTokens.authTopBarInset,
            child: Row(
              children: [
                AuthBackButton(onTap: onBack),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          Positioned(
            top: AppTokens.authTopBarLogoTop,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                label: 'App logo',
                child: Container(
                  width: AppTokens.authTopBarLogoSize,
                  height: AppTokens.authTopBarLogoSize,
                  decoration: BoxDecoration(
                    color: AppTokens.white,
                    borderRadius: BorderRadius.circular(AppTokens.radiusLogo),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: AppTokens.logoIconSize,
                      height: AppTokens.logoIconSize,
                      child: const CustomPaint(painter: AppLogoPainter()),
                    ),
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
