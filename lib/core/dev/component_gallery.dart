import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_cubit.dart';
import '../widgets/widgets.dart';

/// Dev-only gallery to visually verify the Module 2 design system in light and
/// dark. Not part of the product flow — replaced as the splash target by the
/// real Splash screen in the Auth module.
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  int _segment = 0;
  int _chip = 0;
  int _nav = 0;
  final _emailCtrl = TextEditingController(text: 'you@nexveero.app');

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nexveero · Components'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => context.read<ThemeCubit>().toggle(),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _nav,
        onTap: (i) => setState(() => _nav = i),
        items: const [
          AppNavItem(icon: Icons.home_outlined, label: 'Home'),
          AppNavItem(icon: Icons.search, label: 'Search'),
          AppNavItem(icon: Icons.add_circle_outline, label: 'Post'),
          AppNavItem(icon: Icons.chat_bubble_outline, label: 'Chats'),
          AppNavItem(icon: Icons.person_outline, label: 'You'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Display', style: texts.displayLarge),
          Text('Heading 1', style: texts.headlineMedium),
          Text('Title', style: texts.titleMedium),
          Text('Body — the quick brown fox', style: texts.bodyMedium),
          Text('CAPTION / META', style: texts.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            const AppAvatar(name: 'Maya K', ring: true),
            const SizedBox(width: AppSpacing.md),
            const AppAvatar(name: 'Aria Lang'),
            const SizedBox(width: AppSpacing.md),
            AppChip(label: 'All', selected: _chip == 0, onTap: () => setState(() => _chip = 0)),
            const SizedBox(width: AppSpacing.sm),
            AppChip(label: 'Buy', selected: _chip == 1, onTap: () => setState(() => _chip = 1)),
            const SizedBox(width: AppSpacing.sm),
            AppChip(label: 'Sell', selected: _chip == 2, onTap: () => setState(() => _chip = 2)),
          ]),
          const SizedBox(height: AppSpacing.xl),
          AppSegmented(
            segments: const ['Feed', 'Chats', 'You'],
            selectedIndex: _segment,
            onChanged: (i) => setState(() => _segment = i),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            controller: _emailCtrl,
            label: 'Email',
            hint: 'you@nexveero.app',
            prefixIcon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppTextField(
            label: 'Password',
            hint: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscure: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppTextField(
            label: 'Email',
            hint: 'not-an-email',
            prefixIcon: Icons.error_outline,
            errorText: 'Enter a valid email address',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Request this post',
            icon: Icons.bolt,
            onPressed: () => AppOverlays.snack(context, 'Post published', actionLabel: 'Undo', onAction: () {}),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Tonal', variant: AppButtonVariant.tonal, onPressed: () {}),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Leave group',
            variant: AppButtonVariant.outline,
            onPressed: () => AppOverlays.confirm(
              context,
              title: 'Leave group?',
              message: "You'll stop receiving messages from this group.",
              confirmLabel: 'Leave',
              destructive: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppButton(label: 'Disabled', onPressed: null),
          const SizedBox(height: AppSpacing.md),
          const AppButton(label: 'Loading', onPressed: _noop, isLoading: true),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 220,
            child: EmptyView(
              title: 'No posts yet',
              subtitle: 'Follow creators to see their posts here.',
              icon: Icons.photo_library_outlined,
              actionLabel: 'Explore',
              onAction: () {},
            ),
          ),
          SizedBox(
            height: 220,
            child: ErrorView(message: 'No internet connection.', onRetry: () {}),
          ),
        ],
      ),
    );
  }

  static void _noop() {}

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }
}
