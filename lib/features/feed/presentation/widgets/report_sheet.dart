import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Bottom sheet to collect a free-text report reason (POST /loads/{id}/reports).
/// Returns the reason on submit, or null if dismissed.
class ReportSheet extends StatefulWidget {
  const ReportSheet._();

  static Future<String?> show(BuildContext context) {
    return AppOverlays.sheet<String>(
      context,
      builder: (_) => const ReportSheet._(),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _controller = TextEditingController();
  bool get _valid => _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Report post', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _controller,
          hint: 'Tell us what’s wrong with this post…',
          maxLines: 4,
          maxLength: 5000,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Submit report',
          onPressed: _valid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
