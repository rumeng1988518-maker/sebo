import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'step1_binding_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_SlideData> _slides = const [
    _SlideData(image: 'assets/images/screen-0.webp'),
    _SlideData(image: 'assets/images/screen-1.webp'),
    _SlideData(image: 'assets/images/screen-2.webp'),
    _SlideData(image: 'assets/images/screen-3.webp'),
  ];

  void _goToNextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _enterApp();
    }
  }

  void _enterApp() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Step1BindingScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _slides.length,
            itemBuilder: (_, i) => _SlidePage(data: _slides[i]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 32,
                right: 32,
                bottom: MediaQuery.of(context).padding.bottom + 36,
                top: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _slides.length,
                    effect: ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                      spacing: 6,
                      activeDotColor: const Color(0xFF6C5CE7),
                      dotColor: Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: ElevatedButton(
                      key: ValueKey(isLast),
                      onPressed: _goToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLast
                            ? const Color(0xFF00B894)
                            : const Color(0xFF6C5CE7),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isLast ? '立即进入' : '下一步',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _enterApp,
                      child: Text(
                        '跳过',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideData {
  final String image;
  const _SlideData({required this.image});
}

class _SlidePage extends StatelessWidget {
  final _SlideData data;
  const _SlidePage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          data.image,
          fit: BoxFit.cover,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.92),
                  Colors.white,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
