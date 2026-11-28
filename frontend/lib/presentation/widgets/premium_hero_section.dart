import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_tokens.dart';

class PremiumHeroSection extends StatefulWidget {
  final List<String> imageAssets;
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final List<HeroStat> stats;
  final Duration transitionDuration;
  final Duration imageDuration;

  const PremiumHeroSection({
    super.key,
    required this.imageAssets,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.stats,
    this.transitionDuration = const Duration(
      milliseconds: AppTokens.motionHeroTransition,
    ),
    this.imageDuration = const Duration(
      milliseconds: AppTokens.motionHeroImage,
    ),
  });

  @override
  State<PremiumHeroSection> createState() => _PremiumHeroSectionState();
}

class _PremiumHeroSectionState extends State<PremiumHeroSection>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late Timer _autoScrollTimer;
  int _currentPage = 0;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scaleController = AnimationController(
      duration: widget.imageDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: AppTokens.heroScaleEnd)
        .animate(
          CurvedAnimation(
            parent: _scaleController,
            curve: AppTokens.curveEmphasized,
          ),
        );
    _fadeController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: AppTokens.curveEmphasized,
      ),
    );

    _startAutoScroll();
    _scaleController.repeat(reverse: true);
  }

  void _startAutoScroll() {
    if (widget.imageAssets.isEmpty) return;

    _autoScrollTimer = Timer.periodic(widget.imageDuration, (timer) {
      if (_currentPage < widget.imageAssets.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _pageController.animateToPage(
        _currentPage,
        duration: widget.transitionDuration,
        curve: AppTokens.curveHeroPage,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer.cancel();
    _pageController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen =
        MediaQuery.of(context).size.width > AppTokens.heroBreakpoint;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.heroRadius),
        border: Border.all(
          color: widget.statusColor.withValues(alpha: AppTokens.alphaStrong),
          width: AppTokens.componentBorderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: isWideScreen ? _buildWideScreenLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildWideScreenLayout() {
    return SizedBox(
      height: AppTokens.heroWideHeight,
      child: Row(
        children: [
          Expanded(flex: 5, child: _buildTextContent()),
          Expanded(flex: 7, child: _buildImageSequence()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        SizedBox(
          height: AppTokens.heroMobileHeight,
          child: _buildImageSequence(),
        ),
        _buildTextContent(),
      ],
    );
  }

  Widget _buildTextContent() {
    return Container(
      padding: const EdgeInsets.all(AppTokens.heroPadding),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTokens.heroGradientStart, AppTokens.heroGradientEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.heroStatusPaddingH,
              vertical: AppTokens.heroStatusPaddingV,
            ),
            decoration: BoxDecoration(
              color: widget.statusColor.withValues(alpha: AppTokens.alphaLow),
              borderRadius: BorderRadius.circular(AppTokens.radius2xl),
              border: Border.all(
                color: widget.statusColor.withValues(
                  alpha: AppTokens.alphaStrong,
                ),
                width: AppTokens.componentBorderWidth,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppTokens.heroDotSize,
                  height: AppTokens.heroDotSize,
                  decoration: BoxDecoration(
                    color: widget.statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Text(
                  widget.statusLabel,
                  style: AppTokens.dmSans(
                    size: AppTokens.statChangeFontSize,
                    weight: FontWeight.w700,
                    color: widget.statusColor,
                    letterSpacing: AppTokens.heroTrackingStatus,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space2xl),
          Text(
            widget.title,
            style: AppTokens.poppins(
              size: AppTokens.heroTitleSize,
              weight: FontWeight.w900,
              color: AppTokens.white,
              letterSpacing: AppTokens.heroTrackingTight,
              height: AppTokens.heroLineHeightTitle,
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            widget.subtitle,
            style: AppTokens.dmSans(
              size: AppTokens.heroSubtitleSize,
              weight: FontWeight.w400,
              color: AppTokens.white.withValues(alpha: AppTokens.alphaTertiary),
              height: AppTokens.heroLineHeightSubtitle,
              letterSpacing: AppTokens.heroTrackingSubtitle,
            ),
          ),
          const SizedBox(height: AppTokens.space3xl),
          Wrap(
            spacing: AppTokens.space3xl,
            runSpacing: AppTokens.spaceXl,
            children: widget.stats
                .map((stat) => _buildStatColumn(stat))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(HeroStat stat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          style: AppTokens.poppins(
            size: AppTokens.heroStatValueSize,
            weight: FontWeight.w900,
            color: stat.color,
            letterSpacing: AppTokens.heroTrackingStat,
          ),
        ),
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          stat.label,
          style: AppTokens.dmSans(
            size: AppTokens.heroStatLabelSize,
            weight: FontWeight.w600,
            color: AppTokens.white.withValues(alpha: AppTokens.alphaSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSequence() {
    if (widget.imageAssets.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppTokens.heroImageOverlayStart,
              AppTokens.heroGradientEnd,
            ],
            stops: [0.0, 1.0],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            return PageView.builder(
              controller: _pageController,
              itemCount: widget.imageAssets.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage(widget.imageAssets[index]),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    foregroundDecoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppTokens.heroOverlayFadeStart,
                          AppTokens.transparent,
                        ],
                        stops: [0.0, AppTokens.heroOverlayStop],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 0.0;
              if (_pageController.hasClients) {
                value = _pageController.page ?? 0.0;
              }
              return Transform.translate(
                offset: Offset(value * AppTokens.heroParallaxShift, 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: AppTokens.heroRadialRadius,
                      colors: [
                        widget.statusColor.withValues(
                          alpha: AppTokens.alphaMedium,
                        ),
                        AppTokens.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: AppTokens.heroIndicatorOffset,
          right: AppTokens.heroIndicatorOffset,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              widget.imageAssets.length,
              (index) => _buildPageIndicator(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: AppTokens.motionHeroIndicator),
      margin: const EdgeInsets.symmetric(
        horizontal: AppTokens.heroIndicatorGap,
      ),
      width: isActive
          ? AppTokens.heroIndicatorActiveWidth
          : AppTokens.heroIndicatorWidth,
      height: AppTokens.heroIndicatorHeight,
      decoration: BoxDecoration(
        color: isActive
            ? widget.statusColor
            : AppTokens.white.withValues(alpha: AppTokens.alphaStrong),
        borderRadius: BorderRadius.circular(AppTokens.heroIndicatorRadius),
      ),
    );
  }
}

class HeroStat {
  final String value;
  final String label;
  final Color color;

  const HeroStat({
    required this.value,
    required this.label,
    required this.color,
  });
}
