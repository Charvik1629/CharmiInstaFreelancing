part of 'make_offer_cubit.dart';

enum MakeOfferStatus { idle, submitting, success, failure }

class MakeOfferState extends Equatable {
  const MakeOfferState({
    this.priceText = '',
    this.remarks = '',
    this.status = MakeOfferStatus.idle,
    this.errorMessage,
    this.fieldErrors = const {},
    this.created,
  });

  final String priceText;
  final String remarks;
  final MakeOfferStatus status;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
  final Offer? created;

  bool get isSubmitting => status == MakeOfferStatus.submitting;

  /// Price and remarks are both required by the API.
  bool get canSubmit =>
      priceText.trim().isNotEmpty && remarks.trim().isNotEmpty && !isSubmitting;

  MakeOfferState copyWith({
    String? priceText,
    String? remarks,
    MakeOfferStatus? status,
    String? errorMessage,
    bool clearError = false,
    Map<String, String>? fieldErrors,
    Offer? created,
  }) {
    return MakeOfferState(
      priceText: priceText ?? this.priceText,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      fieldErrors: clearError ? const {} : (fieldErrors ?? this.fieldErrors),
      created: created ?? this.created,
    );
  }

  @override
  List<Object?> get props =>
      [priceText, remarks, status, errorMessage, fieldErrors, created];
}
