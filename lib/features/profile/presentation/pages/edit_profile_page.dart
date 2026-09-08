import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_flow.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/repositories/profile_repository.dart';
import '../cubit/edit_profile_cubit.dart';

/// Edit Profile (design "/ Edit Profile"). Seeded from the current user; saves
/// name/bio/phone/avatar via PUT /profile, then updates the session. Avatar
/// picking goes through the Module 7 permission flow.
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) {
      // Not signed in (shouldn't happen behind the auth guard) — bail out.
      return const Scaffold(body: Center(child: Text('No profile to edit')));
    }
    return BlocProvider(
      create: (_) => EditProfileCubit(sl<ProfileRepository>(), user),
      child: _EditProfileView(user: user),
    );
  }
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView({required this.user});

  final User user;

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _picker = ImagePicker();
  late final TextEditingController _name =
      TextEditingController(text: widget.user.name);
  late final TextEditingController _bio =
      TextEditingController(text: widget.user.bio ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.user.phone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final cubit = context.read<EditProfileCubit>();
    final permission =
        source == ImageSource.camera ? AppPermission.camera : AppPermission.photos;
    final outcome = await PermissionFlow.ensure(context, permission);
    if (!outcome.isUsable) return;
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file != null) cubit.setAvatar(file.path);
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not open ${permission.name}');
    }
  }

  void _openAvatarSheet() {
    AppOverlays.sheet<void>(
      context,
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickAvatar(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.of(sheetCtx).pop();
              _pickAvatar(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditProfileCubit, EditProfileState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) async {
        if (state.status == EditStatus.success && state.saved != null) {
          await context.read<AuthCubit>().updateUser(state.saved!);
          if (context.mounted) {
            AppOverlays.snack(context, 'Profile updated');
            context.pop();
          }
        } else if (state.status == EditStatus.failure) {
          AppOverlays.snack(context, state.errorMessage ?? 'Could not save profile');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
          actions: const [_SaveAction()],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Center(child: _AvatarPicker(user: widget.user, onTap: _openAvatarSheet)),
              const SizedBox(height: AppSpacing.xl),
              _Field(
                controller: _name,
                label: 'Name',
                icon: Icons.person_outline,
                errorKey: 'name',
                onChanged: (v) => context.read<EditProfileCubit>().setName(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                controller: _bio,
                label: 'Bio',
                icon: Icons.notes_outlined,
                maxLines: 4,
                maxLength: 1000,
                errorKey: 'bio',
                onChanged: (v) => context.read<EditProfileCubit>().setBio(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Field(
                controller: _phone,
                label: 'Phone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                errorKey: 'phone',
                onChanged: (v) => context.read<EditProfileCubit>().setPhone(v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditProfileCubit, EditProfileState>(
      buildWhen: (p, c) => p.avatarPath != c.avatarPath,
      builder: (context, state) {
        final Widget avatar = state.hasNewAvatar
            ? CircleAvatar(radius: 46, backgroundImage: FileImage(File(state.avatarPath!)))
            : AppAvatar(
                name: user.name,
                imageUrl: MediaUrl.resolve(user.avatarUrl),
                size: 92,
              );
        return Stack(
          children: [
            avatar,
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: onTap,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SaveAction extends StatelessWidget {
  const _SaveAction();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditProfileCubit, EditProfileState>(
      buildWhen: (p, c) =>
          p.canSubmit != c.canSubmit || p.isSubmitting != c.isSubmitting,
      builder: (context, state) {
        if (state.isSubmitting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: TextButton(
            onPressed:
                state.canSubmit ? () => context.read<EditProfileCubit>().submit() : null,
            child: const Text('Save'),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.errorKey,
    required this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String errorKey;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditProfileCubit, EditProfileState>(
      buildWhen: (p, c) => p.fieldErrors[errorKey] != c.fieldErrors[errorKey],
      builder: (context, state) {
        return AppTextField(
          controller: controller,
          label: label,
          prefixIcon: icon,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          errorText: state.fieldErrors[errorKey],
          onChanged: onChanged,
        );
      },
    );
  }
}
