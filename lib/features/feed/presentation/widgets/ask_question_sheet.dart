import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Ask a question about a post (POST /loads/{id}/questions). Matches the design
/// Ask modal (HTML 1699–1738): title, post-title subtitle, "Your question"
/// label and a `Cancel | Submit` row. Returns the question text, or null.
class AskQuestionSheet extends StatefulWidget {
  const AskQuestionSheet._({this.subtitle});
  final String? subtitle;

  static Future<String?> show(BuildContext context, {String? subtitle}) {
    return AppOverlays.sheet<String>(
      context,
      builder: (_) => AskQuestionSheet._(subtitle: subtitle),
    );
  }

  @override
  State<AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends State<AskQuestionSheet> {
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
        Text('Ask a question', style: Theme.of(context).textTheme.titleLarge),
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
        const SheetFieldLabel('Your question'),
        AppTextField(
          controller: _controller,
          hint: 'Type your question…',
          maxLines: 4,
          maxLength: 2000,
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
