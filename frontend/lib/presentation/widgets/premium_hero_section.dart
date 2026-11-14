import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/tailwind.dart';

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
    this.transitionDuration = const Duration(milliseconds: 1500),
    this.imageDuration = const Duration(seconds: 4),
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
    
    // Scale animation controller for subtle zoom effect
    _scaleController = AnimationController(
      duration: widget.imageDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    
    // Fade animation for smooth transitions
    _fadeController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _startAutoScroll();
    _scaleController.repeat(reverse: true);
  }

  void _startAutoScroll() {
    // No images to cycle — skip the timer entirely to avoid a no-op loop.
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
        curve: Curves.easeInOutCubic,
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
    final isWideScreen = MediaQuery.of(context).size.width > 768;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.statusColor.withOpacity(0.25),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: isWideScreen
          ? _buildWideScreenLayout()
          : _buildMobileLayout(),
    );
  }

  Widget _buildWideScreenLayout() {
    return SizedBox(
      height: 400,
      child: Row(
        children: [
          // Left side - Static text content
          Expanded(
            flex: 5,
            child: _buildTextContent(),
          ),
          // Right side - Immersive background visual
          Expanded(
            flex: 7,
            child: _buildImageSequence(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Top - Image visual (reduced height on mobile)
        SizedBox(
          height: 280,
          child: _buildImageSequence(),
        ),
        // Bottom - Text content
        _buildTextContent(),
      ],
    );
  }

  Widget _buildTextContent() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1F0A),
            const Color(0xFF050D18),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.statusColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.statusLabel,
                  style: TextStyle(
                    color: widget.statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          Text(
            widget.title,
            style: const TextStyle(
              color: TwColors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          
          // Subtitle
          Text(
            widget.subtitle,
            style: TextStyle(
              color: TwColors.white.withOpacity(0.6),
              fontSize: 16,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 32),
          
          // Stats row
          Wrap(
            spacing: 32,
            runSpacing: 20,
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
          style: TextStyle(
            color: stat.color,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          stat.label,
          style: TextStyle(
            color: TwColors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSequence() {
    // No image assets supplied — render the gradient background only so the
    // hero still looks correct without any missing-asset exceptions.
    if (widget.imageAssets.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black.withOpacity(0.45),
              const Color(0xFF050D18),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated page view for smooth transitions
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
                        image:AssetImage(widget.imageAssets[index]),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    // Gradient overlay for better text readability
                    foregroundDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        
        // Parallax overlay effect
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 0.0;
              if (_pageController.hasClients) {
                value = _pageController.page ?? 0.0;
              }
              return Transform.translate(
                offset: Offset(value * 30, 0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.5,
                      colors: [
                        widget.statusColor.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Page indicators
        Positioned(
          bottom: 24,
          right: 24,
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
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? widget.statusColor
            : TwColors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
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
