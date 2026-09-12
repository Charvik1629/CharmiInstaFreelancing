import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Admin · Create broadcast group (design "Admin · Create broadcast group",
/// HTML 3988): a name + member picker. Gated — no backend endpoint yet, so Save
/// surfaces that; the form matches the design and is ready to wire.
class CreateBroadcastGroupPage extends StatefulWidget {
  const CreateBroadcastGroupPage({super.key});

  @override
  State<CreateBroadcastGroupPage> createState() =>
      _CreateBroadcastGroupPageState();
}

class _CreateBroadcastGroupPageState extends State<CreateBroadcastGroupPage> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New broadcast group')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          AppTextField(
            controller: _name,
            label: 'Group name',
            hint: 'e.g. Premium buyers',
            prefixIcon: Icons.groups_2_outlined,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppTextField(
            label: 'Add members',
            hint: 'Search people to add…',
            prefixIcon: Icons.person_add_alt,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Create group',
            onPressed: () => AppOverlays.snack(context,
                'Broadcast groups need a backend endpoint (not in the API docs yet).'),
          ),
        ],
      ),
    );
  }
}
