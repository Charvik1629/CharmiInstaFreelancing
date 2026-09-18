import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/user.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_flow.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../feed/presentation/widgets/tag_picker_sheet.dart';
import '../../../tags/domain/entities/tag.dart';
import '../../domain/entities/profile_update.dart';
import '../cubit/business_details_cubit.dart';

/// "Fill Business Details" (design). Post-approval onboarding form. Core fields
/// (name/phone/logo) save today; the extended business fields persist once the
/// backend adds them (BACKEND_REQUIREMENTS B1) — the full payload is sent either
/// way, so the screen is complete now.
class BusinessDetailsPage extends StatelessWidget {
  const BusinessDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().state.user;
    return BlocProvider(
      create: (_) => sl<BusinessDetailsCubit>(),
      child: _BusinessDetailsView(user: user),
    );
  }
}

class _BusinessDetailsView extends StatefulWidget {
  const _BusinessDetailsView({this.user});
  final User? user;

  @override
  State<_BusinessDetailsView> createState() => _BusinessDetailsViewState();
}

class _BusinessDetailsViewState extends State<_BusinessDetailsView> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _business =
      TextEditingController(text: widget.user?.businessName ?? '');
  final _msme = TextEditingController();
  final _association = TextEditingController();
  late final _phone = TextEditingController(text: widget.user?.phone ?? '');
  final _website = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _description = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _linkedin = TextEditingController();
  final _productInput = TextEditingController();

  static const _companyTypes = [
    'Proprietorship',
    'Partnership',
    'Private Limited',
    'LLP',
    'Other',
  ];
  String _companyType = _companyTypes.first;
  final List<String> _products = [];
  List<Tag> _tags = const [];
  String? _logoPath;

  @override
  void dispose() {
    for (final c in [
      _name, _business, _msme, _association, _phone, _website, _address,
      _city, _state, _pincode, _description, _instagram, _facebook,
      _linkedin, _productInput,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final outcome = await PermissionFlow.ensure(context, AppPermission.photos);
    if (!outcome.isUsable) return;
    try {
      final f = await _picker.pickImage(
          source: ImageSource.gallery, maxWidth: 800, imageQuality: 88);
      if (f != null) setState(() => _logoPath = f.path);
    } catch (_) {
      if (mounted) AppOverlays.snack(context, 'Could not attach logo');
    }
  }

  void _addProduct() {
    final v = _productInput.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _products.add(v);
      _productInput.clear();
    });
  }

  Future<void> _pickTags() async {
    final picked = await AppOverlays.sheet<List<Tag>>(
      context,
      builder: (_) => TagPickerSheet(initial: _tags),
    );
    if (picked != null) setState(() => _tags = picked);
  }

  String? _orNull(String s) => s.trim().isEmpty ? null : s.trim();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final social = <String, String>{
      if (_instagram.text.trim().isNotEmpty) 'instagram': _instagram.text.trim(),
      if (_facebook.text.trim().isNotEmpty) 'facebook': _facebook.text.trim(),
      if (_linkedin.text.trim().isNotEmpty) 'linkedin': _linkedin.text.trim(),
    };
    context.read<BusinessDetailsCubit>().submit(ProfileUpdate(
          name: _orNull(_name.text),
          businessName: _orNull(_business.text),
          companyType: _companyType,
          msmeNumber: _orNull(_msme.text),
          association: _orNull(_association.text),
          phone: _orNull(_phone.text),
          website: _orNull(_website.text),
          address: _orNull(_address.text),
          city: _orNull(_city.text),
          state: _orNull(_state.text),
          pincode: _orNull(_pincode.text),
          description: _orNull(_description.text),
          products: _products.isEmpty ? null : List.of(_products),
          tagIds: _tags.isEmpty ? null : _tags.map((t) => t.id).toList(),
          socialLinks: social.isEmpty ? null : social,
          logoPath: _logoPath,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final gst = widget.user?.gstNumber;

    return Scaffold(
      appBar: AppBar(title: const Text('Business details')),
      body: BlocConsumer<BusinessDetailsCubit, BusinessDetailsState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          if (state.status == BdStatus.success) {
            AppOverlays.snack(context, 'Business details saved');
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.feed);
            }
          } else if (state.status == BdStatus.failure) {
            AppOverlays.snack(context, state.errorMessage ?? 'Could not save');
          }
        },
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
              children: [
                Text(
                  'Complete your profile so buyers can find and trust you. '
                  'This unlocks your verified badge.',
                  style: TextStyle(color: nex.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel('Business'),
                _logoRow(nex),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _business,
                  label: 'Business / firm name',
                  hint: 'Enter business name',
                ),
                const SizedBox(height: AppSpacing.md),
                _companyTypeField(),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    controller: _msme, label: 'MSME / Udyam no.', hint: 'Enter MSME / Udyam no.'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    controller: _association,
                    label: 'Association / body',
                    hint: 'Enter association'),

                _sectionLabel('KYC'),
                if ((gst ?? '').isNotEmpty)
                  _readonly('GST number', gst!)
                else
                  Text('KYC captured at registration.',
                      style: TextStyle(color: nex.textSecondary, fontSize: 13)),

                _sectionLabel('Contact'),
                AppTextField(
                    controller: _phone,
                    label: 'Mobile',
                    hint: 'Enter mobile number',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    controller: _website,
                    label: 'Website',
                    hint: 'Enter website',
                    keyboardType: TextInputType.url),

                _sectionLabel('Address'),
                AppTextField(
                    controller: _address,
                    label: 'Address line',
                    hint: 'Enter address'),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 2,
                        child: AppTextField(
                            controller: _city, label: 'City', hint: 'Enter city')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: AppTextField(
                            controller: _state, label: 'State', hint: 'Enter state')),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: AppTextField(
                            controller: _pincode,
                            label: 'PIN',
                            hint: 'Enter pincode',
                            keyboardType: TextInputType.number)),
                  ],
                ),

                _sectionLabel('Catalogue'),
                _productsField(nex),
                const SizedBox(height: AppSpacing.md),
                _tagsField(nex),

                _sectionLabel('About'),
                AppTextField(
                  controller: _description,
                  label: 'Description',
                  hint: 'What your business does…',
                  maxLines: 4,
                  maxLength: 1020,
                ),
                const SizedBox(height: AppSpacing.md),
                _sectionLabel('Social links'),
                AppTextField(
                    controller: _instagram,
                    label: 'Instagram',
                    hint: 'Enter Instagram'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    controller: _facebook, label: 'Facebook', hint: 'Enter Facebook page'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    controller: _linkedin, label: 'LinkedIn', hint: 'Enter LinkedIn profile'),

                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save & continue',
                  isLoading: state.isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.xl, 0, AppSpacing.sm),
        child: Text(s.toUpperCase(),
            style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: .5,
                color: context.nexveero.gradientStart)),
      );

  Widget _logoRow(NexveeroColors nex) => Row(
        children: [
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: nex.border),
                image: _logoPath == null
                    ? null
                    : DecorationImage(
                        image: FileImage(File(_logoPath!)), fit: BoxFit.cover),
              ),
              child: _logoPath != null
                  ? null
                  : Icon(Icons.add_a_photo_outlined, color: nex.iconInactive),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Company logo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('PNG/JPG · up to 2 MB',
                    style: TextStyle(color: nex.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      );

  Widget _companyTypeField() => InputDecorator(
        decoration: const InputDecoration(labelText: 'Company type'),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _companyType,
            isExpanded: true,
            items: [
              for (final t in _companyTypes)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (v) => setState(() => _companyType = v ?? _companyType),
          ),
        ),
      );

  Widget _readonly(String label, String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.nexveero.elevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: context.nexveero.border),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user_outlined,
                size: 18, color: context.nexveero.success),
            const SizedBox(width: AppSpacing.sm),
            Text('$label · $value',
                style: TextStyle(color: context.nexveero.textSecondary)),
          ],
        ),
      );

  Widget _productsField(NexveeroColors nex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                controller: _productInput,
                label: 'Products',
                hint: 'Add a product',
                onSubmitted: (_) => _addProduct(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
                label: 'Add', variant: AppButtonVariant.tonal, expanded: false, onPressed: _addProduct),
          ],
        ),
        if (_products.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final p in _products)
                Chip(
                  label: Text(p),
                  onDeleted: () => setState(() => _products.remove(p)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tagsField(NexveeroColors nex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TAGS (5–10)',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .6,
                color: nex.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: _pickTags,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: nex.border),
            ),
            child: _tags.isEmpty
                ? Text('Choose tags', style: TextStyle(color: nex.iconInactive))
                : Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [for (final t in _tags) Chip(label: Text(t.name))],
                  ),
          ),
        ),
      ],
    );
  }
}
