part of 'edit_profile_cubit.dart';

enum EditStatus { idle, submitting, success, failure }

class EditProfileState extends Equatable {
  const EditProfileState({
    this.name = '',
    this.bio = '',
    this.phone = '',
    this.avatarPath,
    this.status = EditStatus.idle,
    this.errorMessage,
    this.fieldErrors = const {},
    this.saved,
  });

  final String name;
  final String bio;
  final String phone;
  final String? avatarPath;

  final EditStatus status;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  /// The updated user once [status] is success.
  final User? saved;

  bool get isSubmitting => status == EditStatus.submitting;
  bool get hasNewAvatar => avatarPath != null && avatarPath!.isNotEmpty;

  /// Name is the one field the API keeps required-in-spirit; block empty names.
  bool get canSubmit => name.trim().isNotEmpty && !isSubmitting;

  EditProfileState copyWith({
    String? name,
    String? bio,
    String? phone,
    String? avatarPath,
    EditStatus? status,
    String? errorMessage,
    bool clearError = false,
    Map<String, String>? fieldErrors,
    User? saved,
  }) {
    return EditProfileState(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      avatarPath: avatarPath ?? this.avatarPath,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: clearError ? const {} : (fieldErrors ?? this.fieldErrors),
      saved: saved ?? this.saved,
    );
  }

  @override
  List<Object?> get props =>
      [name, bio, phone, avatarPath, status, errorMessage, fieldErrors, saved];
}
