import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Simple client-side password strength meter (design: "Strong password").
/// Scores length + character variety; purely advisory.
class PasswordStrength {
  const PasswordStrength(this.score, this.label);
  final int score; // 0..4
  final String label;

  static PasswordStrength of(String value) {
    if (value.isEmpty) return const PasswordStrength(0, '');
    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(value) && RegExp(r'[a-z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value) && RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    const labels = ['Too weak', 'Weak', 'Okay', 'Good', 'Strong password'];
    return PasswordStrength(score, labels[score.clamp(0, 4)]);
  }
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final s = PasswordStrength.of(password);
    if (password.isEmpty) return const SizedBox.shrink();
    final colors = [
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.error,
      context.nexveero.warning,
      context.nexveero.teal,
      context.nexveero.success,
    ];
    final color = colors[s.score.clamp(0, 4)];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: (s.score / 4).clamp(0.1, 1.0),
                minHeight: 5,
                backgroundColor: context.nexveero.border,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(s.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
