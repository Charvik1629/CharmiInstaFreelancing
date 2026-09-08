import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/wallet_settings.dart';
import '../cubit/admin_wallet_settings_cubit.dart';

/// Admin · Post & boost pricing (design). Edits the wallet economy settings
/// (`/admin/wallet/settings`): post cost, boost cost & duration, business boost,
/// and broadcast costs.
class AdminPricingPage extends StatelessWidget {
  const AdminPricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminWalletSettingsCubit>()..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Post & boost pricing')),
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
                message: state.errorMessage ?? 'Could not load pricing',
                onRetry: () => context.read<AdminWalletSettingsCubit>().load(),
              );
            }
            return _PricingForm(settings: state.settings!, saving: state.saving);
          },
        ),
      ),
    );
  }
}

class _PricingForm extends StatefulWidget {
  const _PricingForm({required this.settings, required this.saving});
  final WalletSettings settings;
  final bool saving;

  @override
  State<_PricingForm> createState() => _PricingFormState();
}

class _PricingFormState extends State<_PricingForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _c = {
      'post_credit_cost': TextEditingController(text: '${s.postCreditCost}'),
      'boost_credit_cost': TextEditingController(text: '${s.boostCreditCost}'),
      'boost_duration_hours':
          TextEditingController(text: '${s.boostDurationHours}'),
      'business_boost_credit_cost':
          TextEditingController(text: '${s.businessBoostCreditCost}'),
      'broadcast_credit_cost':
          TextEditingController(text: '${s.broadcastCreditCost}'),
      'broadcast_message_credit_cost':
          TextEditingController(text: '${s.broadcastMessageCreditCost}'),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changes = <String, dynamic>{
      for (final e in _c.entries) e.key: int.parse(e.value.text.trim()),
    };
    final ok = await context.read<AdminWalletSettingsCubit>().save(changes);
    if (mounted && ok) AppOverlays.snack(context, 'Pricing updated');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('CREDIT COSTS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.nexveero.textSecondary, letterSpacing: 1)),
          const SizedBox(height: AppSpacing.md),
          _field('post_credit_cost', 'Credits per post', Icons.toll_outlined),
          _field('boost_credit_cost', 'Credits per post boost',
              Icons.rocket_launch_outlined),
          _field('boost_duration_hours', 'Boost duration (hours)',
              Icons.schedule_outlined),
          _field('business_boost_credit_cost', 'Credits per business boost',
              Icons.storefront_outlined),
          _field('broadcast_credit_cost', 'Credits per broadcast',
              Icons.campaign_outlined),
          _field('broadcast_message_credit_cost',
              'Credits per broadcast message', Icons.sms_outlined),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Save settings',
            isLoading: widget.saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _field(String key, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: FormField<String>(
        initialValue: _c[key]!.text,
        validator: (_) {
          final n = int.tryParse(_c[key]!.text.trim());
          if (n == null) return 'Enter a number';
          if (n < 0) return 'Cannot be negative';
          return null;
        },
        builder: (fieldState) => AppTextField(
          controller: _c[key],
          label: label,
          prefixIcon: icon,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: fieldState.didChange,
          errorText: fieldState.errorText,
        ),
      ),
    );
  }
}
