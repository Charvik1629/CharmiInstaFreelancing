import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Report a post (POST /loads/{id}/reports). Matches the design's Report modal
/// (HTML 1783–1866): title, post-title subtitle, "Reason / details" label and a
/// `Cancel | Submit` row. Returns the reason on submit, or null if dismissed.
class ReportSheet extends StatefulWidget {
  const ReportSheet._({this.subtitle});
  final String? subtitle;

  static Future<String?> show(BuildContext context, {String? subtitle}) {
    return AppOverlays.sheet<String>(
      context,
      builder: (_) => ReportSheet._(subtitle: subtitle),
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
        if ((widget.subtitle ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.nexveero.textSecondary)),
        ],
        const SizedBox(height: AppSpacing.lg),
        const SheetFieldLabel('Reason / details'),
        AppTextField(
          controller: _controller,
          hint: 'Tell us what’s wrong with this post…',
          maxLines: 4,
          maxLength: 5000,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Submit',
                onPressed: _valid
                    ? () => Navigator.of(context).pop(_controller.text.trim())
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
