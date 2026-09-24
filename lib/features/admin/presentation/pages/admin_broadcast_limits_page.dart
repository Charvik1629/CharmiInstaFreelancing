import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/wallet_settings.dart';
import '../cubit/admin_wallet_settings_cubit.dart';

/// Admin · Broadcast limits (design "Admin · Broadcast limit settings", HTML
/// 3683). Free lists/messages per user, rolling periods, and overage credit
/// costs. Backed by the wallet economy settings (`/admin/wallet/settings`),
/// which carries the broadcast free limits, periods and overage costs.
class AdminBroadcastLimitsPage extends StatelessWidget {
  const AdminBroadcastLimitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminWalletSettingsCubit>()..load(),
      child: Scaffold(
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
        body: BlocConsumer<AdminWalletSettingsCubit, AdminWalletSettingsState>(
          listenWhen: (p, c) =>
              p.errorMessage != c.errorMessage && c.errorMessage != null,
          listener: (context, state) =>
              AppOverlays.snack(context, state.errorMessage!),
          builder: (context, state) {
            if (state.status == SettingsStatus.loading ||
                state.status == SettingsStatus.initial) {
              return const LoadingView();
            }
            if (state.status == SettingsStatus.error) {
              return ErrorView(
                message: state.errorMessage ?? 'Could not load broadcast limits',
                onRetry: () =>
                    context.read<AdminWalletSettingsCubit>().load(),
              );
            }
            return _LimitsForm(settings: state.settings!, saving: state.saving);
          },
        ),
      ),
    );
  }
}

class _LimitsForm extends StatefulWidget {
  const _LimitsForm({required this.settings, required this.saving});
  final WalletSettings settings;
  final bool saving;

  @override
  State<_LimitsForm> createState() => _LimitsFormState();
}

class _LimitsFormState extends State<_LimitsForm> {
  final _formKey = GlobalKey<FormState>();

  // Valid rolling-window periods (see PUT /admin/wallet/settings docs).
  static const _periods = <String>[
    'daily',
    'weekly',
    'monthly',
    '3_months',
    '6_months',
    '9_months',
    '12_months',
  ];

  late final TextEditingController _freeLists;
  late final TextEditingController _listCredits;
  late final TextEditingController _freeMsgs;
  late final TextEditingController _msgCredits;
  late String _listPeriod;
  late String _msgPeriod;

  String _safePeriod(String raw) => _periods.contains(raw) ? raw : 'monthly';

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _freeLists = TextEditingController(text: '${s.broadcastListFreeLimit}');
    _listCredits = TextEditingController(text: '${s.broadcastCreditCost}');
    _freeMsgs = TextEditingController(text: '${s.broadcastMessageFreeLimit}');
    _msgCredits =
        TextEditingController(text: '${s.broadcastMessageCreditCost}');
    _listPeriod = _safePeriod(s.broadcastListPeriod);
    _msgPeriod = _safePeriod(s.broadcastMessagePeriod);
  }

  @override
  void dispose() {
    _freeLists.dispose();
    _listCredits.dispose();
    _freeMsgs.dispose();
    _msgCredits.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changes = <String, dynamic>{
      'broadcast_list_free_limit': int.parse(_freeLists.text.trim()),
      'broadcast_list_period': _listPeriod,
      'broadcast_credit_cost': int.parse(_listCredits.text.trim()),
      'broadcast_message_free_limit': int.parse(_freeMsgs.text.trim()),
      'broadcast_message_period': _msgPeriod,
      'broadcast_message_credit_cost': int.parse(_msgCredits.text.trim()),
    };
    final ok = await context.read<AdminWalletSettingsCubit>().save(changes);
    if (mounted && ok) AppOverlays.snack(context, 'Broadcast limits updated');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
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
            isLoading: widget.saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _num(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: FormField<String>(
          initialValue: c.text,
          validator: (_) {
            final n = int.tryParse(c.text.trim());
            if (n == null) return 'Enter a number';
            if (n < 0) return 'Cannot be negative';
            return null;
          },
          builder: (fieldState) => AppTextField(
            controller: c,
            label: label,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: fieldState.didChange,
            errorText: fieldState.errorText,
          ),
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
                  items: [
                    for (final p in _periods)
                      DropdownMenuItem(
                          value: p, child: Text(p.replaceAll('_', ' '))),
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
