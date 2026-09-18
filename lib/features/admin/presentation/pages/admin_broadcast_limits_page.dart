import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Admin · Broadcast limits (design "Admin · Broadcast limit settings", HTML
/// 3683). Free lists/messages per user, periods, and overage credit costs. The
/// broadcast credit costs persist via admin wallet settings; the free-limit and
/// period fields need a dedicated backend endpoint (pending), so Save surfaces
/// that until it exists.
class AdminBroadcastLimitsPage extends StatefulWidget {
  const AdminBroadcastLimitsPage({super.key});

  @override
  State<AdminBroadcastLimitsPage> createState() =>
      _AdminBroadcastLimitsPageState();
}

class _AdminBroadcastLimitsPageState extends State<AdminBroadcastLimitsPage> {
  final _freeLists = TextEditingController(text: '3');
  final _listCredits = TextEditingController(text: '15');
  final _freeMsgs = TextEditingController(text: '3');
  final _msgCredits = TextEditingController(text: '5');
  String _listPeriod = 'monthly';
  String _msgPeriod = 'monthly';

  @override
  void dispose() {
    _freeLists.dispose();
    _listCredits.dispose();
    _freeMsgs.dispose();
    _msgCredits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast limits'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: 6),
              child: Text('Admin only',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg,
            AppSpacing.lg + MediaQuery.paddingOf(context).bottom),
        children: [
          _Group(
            label: 'PER CHAT LIST',
            children: [
              _num('Free lists per user', _freeLists),
              _period('Broadcast list period', _listPeriod,
                  (v) => setState(() => _listPeriod = v)),
              _num('Credits after free limit', _listCredits),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Group(
            label: 'PER MESSAGE',
            children: [
              _num('Free messages per user', _freeMsgs),
              _period('Broadcast message period', _msgPeriod,
                  (v) => setState(() => _msgPeriod = v)),
              _num('Credits after free limit', _msgCredits),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Save limits',
            onPressed: () => AppOverlays.snack(context,
                'Broadcast costs live in Post & boost pricing; free-limit periods need a backend endpoint.'),
          ),
        ],
      ),
    );
  }

  Widget _num(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppTextField(
          controller: c,
          label: label,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      );

  Widget _period(String label, String value, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.nexveero.textSecondary, letterSpacing: 0.6)),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: context.nexveero.elevated,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: value,
                  items: const [
                    DropdownMenuItem(value: 'daily', child: Text('daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('monthly')),
                  ],
                  onChanged: (v) => onChanged(v ?? value),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.nexveero.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.nexveero.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
