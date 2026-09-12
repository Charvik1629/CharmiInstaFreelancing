import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// The small sentence-case bold field label used inside the design's modal
/// cards (e.g. "Remarks", "Offer price", "Your question", "Reason / details" —
/// HTML 1636–1638). Distinct from [AppTextField]'s uppercase form label.
class SheetFieldLabel extends StatelessWidget {
  const SheetFieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)
              .copyWith(color: context.nexveero.textSecondary),
        ),
      ),
    );
  }
}
