import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/storage/storage_manager.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

class _Slide {
  const _Slide(this.asset, this.title, this.body);
  final String asset;
  final String title;
  final String body;
}

/// Five-slide intro (design "Onboarding 1 of 3"). Cross-fades between slides,
/// Skip jumps to login, the last slide's button finishes onboarding. Sets the
/// `onboarding_seen` flag so it never shows again.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  static const _slides = [
    _Slide(
      'assets/illustrations/onboarding_1.png',
      'Discover. Connect. Grow.',
      'Explore businesses, discover products and connect with opportunities — all in one place.',
    ),
    _Slide(
      'assets/illustrations/onboarding_2.png',
      'Your Business. Your Spotlight.',
      'Share products, photos, videos and updates. Let the right people discover what you offer.',
    ),
    _Slide(
      'assets/illustrations/onboarding_3.png',
      'Conversations on Your Terms.',
      'Chat one-to-one or in groups. Add PIN protection and decide who can start a conversation with you.',
    ),
    _Slide(
      'assets/illustrations/onboarding_4.png',
      'One Message. Wider Reach.',
      'Create broadcast lists, connect with communities and share updates with your network.',
    ),
    _Slide(
      'assets/illustrations/onboarding_5.png',
      'Keep Your Network Alive.',
      'Share everyday updates, explore business profiles and stay connected with the people who matter.',
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  Future<void> _finish() async {
    await sl<StorageManager>().setBool(StorageKeys.onboardingSeen, value: true);
    if (mounted) context.go(AppRoutes.login);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nexveero = context.nexveero;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(color: nexveero.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: active ? nexveero.primaryGradient : null,
                          color: active ? null : nexveero.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                  _NextButton(isLast: _isLast, onTap: _next),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Image.asset(
              slide.asset,
              height: MediaQuery.sizeOf(context).height * 0.38,
              fit: BoxFit.contain,
              errorBuilder: (context, _, _) => Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  gradient: context.nexveero.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.image, size: 84, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            slide.title,
            style: texts.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            style: texts.bodyLarge?.copyWith(
              color: context.nexveero.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.isLast, required this.onTap});
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: isLast ? AppSpacing.xl : 0),
        width: isLast ? null : 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: context.nexveero.primaryGradient,
          shape: isLast ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isLast ? BorderRadius.circular(AppRadius.full) : null,
        ),
        child: isLast
            ? const Text(
                'Get started',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              )
            : const Icon(Icons.arrow_forward, color: Colors.white),
      ),
    );
  }
}
