import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// A validated text field for auth forms: combines a local [validator] with an
/// optional [serverError] (422 field message), wrapping [AppTextField] in a
/// FormField so `Form.validate()` works.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.serverError,
    this.textInputAction,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? serverError;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: controller.text,
      validator: (_) => validator?.call(controller.text),
      builder: (field) {
        return AppTextField(
          controller: controller,
          label: label,
          hint: hint,
          prefixIcon: icon,
          obscure: obscure,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction ??
              (onSubmitted != null
                  ? TextInputAction.done
                  : TextInputAction.next),
          onChanged: field.didChange,
          onSubmitted: onSubmitted,
          errorText: serverError ?? field.errorText,
        );
      },
    );
  }
}

/// The Nexveero app-icon brand mark used atop auth screens.
class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Image.asset(
        'assets/app_icon/nexveero_app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(gradient: context.nexveero.primaryGradient),
          alignment: Alignment.center,
          child: Text(
            'N',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
