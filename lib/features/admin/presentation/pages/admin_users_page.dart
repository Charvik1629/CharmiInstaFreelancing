import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter/services.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/user_approval.dart';
import '../../domain/repositories/admin_wallet_repository.dart';
import '../cubit/admin_users_cubit.dart';

/// Admin · User approval (design "Pending users"). Super-admin reviews new
/// signups: Pending / Approved / Rejected tabs with per-account Approve / Reject.
/// A pending account cannot log in until approved here.
class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminUsersCubit>()..load(),
      child: const _UsersView(),
    );
  }
}

class _UsersView extends StatelessWidget {
  const _UsersView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User approvals')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: BlocBuilder<AdminUsersCubit, AdminUsersState>(
              buildWhen: (p, c) => p.filter != c.filter,
              builder: (context, state) => AppSegmented(
                segments: const ['Pending', 'Approved', 'Rejected'],
                selectedIndex: UserApprovalStatus.values.indexOf(state.filter),
                onChanged: (i) => context
                    .read<AdminUsersCubit>()
                    .setFilter(UserApprovalStatus.values[i]),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<AdminUsersCubit, AdminUsersState>(
              builder: (context, state) {
                switch (state.status) {
                  case UsersStatus.loading:
                  case UsersStatus.initial:
                    return const LoadingView();
                  case UsersStatus.error:
                    return ErrorView(
                      message: state.errorMessage ?? 'Could not load users',
                      onRetry: () => context.read<AdminUsersCubit>().load(),
                    );
                  case UsersStatus.empty:
                    return EmptyView(
                      title: 'Nothing here',
                      subtitle:
                          'No ${state.filter.label.toLowerCase()} accounts.',
                      icon: Icons.how_to_reg_outlined,
                    );
                  case UsersStatus.loaded:
                    return RefreshIndicator(
                      onRefresh: () =>
                          context.read<AdminUsersCubit>().refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        itemCount: state.users.length,
                        itemBuilder: (context, i) => _UserCard(
                          user: state.users[i],
                          filter: state.filter,
                          busy: state.actingOnId == state.users[i].id,
                        ),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.filter,
    required this.busy,
  });

  final User user;
  final UserApprovalStatus filter;
  final bool busy;

  Future<void> _approve(BuildContext context) async {
    final ok = await context.read<AdminUsersCubit>().approve(user);
    if (context.mounted) {
      AppOverlays.snack(
          context, ok ? '${user.name} approved' : 'Could not approve');
    }
  }

  Future<void> _reject(BuildContext context) async {
    final ok = await context.read<AdminUsersCubit>().reject(user);
    if (context.mounted) {
      AppOverlays.snack(
          context, ok ? '${user.name} rejected' : 'Could not reject');
    }
  }

  Future<void> _adjustCredits(BuildContext context) async {
    final input = await showDialog<_Adjustment>(
      context: context,
      builder: (_) => _AdjustCreditsDialog(userName: user.name),
    );
    if (input == null || !context.mounted) return;
    final res = await sl<AdminWalletRepository>().adjustUser(
      userId: user.id,
      amount: input.amount,
      direction: input.direction,
      note: input.note,
    );
    if (!context.mounted) return;
    switch (res) {
      case Success(value: final balance):
        AppOverlays.snack(context, 'New balance: $balance credits');
      case Err(failure: final f):
        AppOverlays.snack(context, f.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = Theme.of(context).textTheme;
    final nex = context.nexveero;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: nex.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(name: user.name, imageUrl: user.avatarUrl, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.businessName ?? user.name,
                        style: texts.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (user.businessName != null)
                      Text(user.name,
                          style: texts.bodySmall
                              ?.copyWith(color: nex.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _line(context, Icons.alternate_email, user.email),
          _line(context, Icons.phone_outlined, user.phone),
          _line(context, Icons.badge_outlined, _kyc(user)),
          if ((user.referralCode ?? '').isNotEmpty)
            _line(context, Icons.card_giftcard_outlined,
                'Referral: ${user.referralCode}'),
          if (filter == UserApprovalStatus.pending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Approve',
                    isLoading: busy,
                    onPressed: () => _approve(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    variant: AppButtonVariant.outline,
                    onPressed: busy ? null : () => _reject(context),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  filter.label,
                  style: texts.labelSmall?.copyWith(
                    color: filter == UserApprovalStatus.approved
                        ? nex.success
                        : nex.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (filter == UserApprovalStatus.approved)
                  TextButton.icon(
                    onPressed: () => _adjustCredits(context),
                    icon: const Icon(Icons.toll_outlined, size: 18),
                    label: Text('${user.creditBalance} credits'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _kyc(User u) {
    if ((u.gstNumber ?? '').isNotEmpty) return 'GST ${u.gstNumber}';
    final parts = [
      if ((u.panNumber ?? '').isNotEmpty) 'PAN ${u.panNumber}',
      if ((u.aadhaarNumber ?? '').isNotEmpty) 'Aadhaar ${u.aadhaarNumber}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _line(BuildContext context, IconData icon, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final nex = context.nexveero;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: nex.iconInactive),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: nex.textSecondary)),
          ),
        ],
      ),
    );
  }
}

/// The result of the adjust-credits dialog.
class _Adjustment {
  const _Adjustment(this.amount, this.direction, this.note);
  final int amount;
  final String direction; // 'credit' | 'debit'
  final String? note;
}

/// Dialog to manually credit or debit a user's wallet (admin).
class _AdjustCreditsDialog extends StatefulWidget {
  const _AdjustCreditsDialog({required this.userName});
  final String userName;

  @override
  State<_AdjustCreditsDialog> createState() => _AdjustCreditsDialogState();
}

class _AdjustCreditsDialogState extends State<_AdjustCreditsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _direction = 'credit';

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_Adjustment(
      int.parse(_amount.text.trim()),
      _direction,
      _note.text.trim().isEmpty ? null : _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adjust credits · ${widget.userName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'credit', label: Text('Add')),
                ButtonSegment(value: 'debit', label: Text('Remove')),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Amount (credits)'),
              validator: (_) {
                final n = int.tryParse(_amount.text.trim());
                if (n == null || n < 1) return 'Enter at least 1';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }
}
