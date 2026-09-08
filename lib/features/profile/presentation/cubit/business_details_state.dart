part of 'business_details_cubit.dart';

enum BdStatus { idle, submitting, success, failure }

class BusinessDetailsState extends Equatable {
  const BusinessDetailsState({
    this.status = BdStatus.idle,
    this.saved,
    this.errorMessage,
    this.fieldErrors = const {},
  });

  final BdStatus status;
  final User? saved;
  final String? errorMessage;
  final Map<String, String> fieldErrors;

  bool get isSubmitting => status == BdStatus.submitting;

  BusinessDetailsState copyWith({
    BdStatus? status,
    User? saved,
    String? errorMessage,
    bool clearError = false,
    Map<String, String>? fieldErrors,
  }) {
    return BusinessDetailsState(
      status: status ?? this.status,
      saved: saved ?? this.saved,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: clearError ? const {} : (fieldErrors ?? this.fieldErrors),
    );
  }

  @override
  List<Object?> get props => [status, saved, errorMessage, fieldErrors];
}
