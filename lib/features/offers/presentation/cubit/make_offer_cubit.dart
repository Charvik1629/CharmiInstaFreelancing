import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/offer.dart';
import '../../domain/repositories/offers_repository.dart';

part 'make_offer_state.dart';

/// Drives the "Make an offer" sheet: a price + remarks, submitted to
/// POST /loads/{id}/offers. The API rejects a second offer (409) — that message
/// is surfaced as-is.
class MakeOfferCubit extends Cubit<MakeOfferState> {
  MakeOfferCubit(this._repository, this.loadId) : super(const MakeOfferState());

  final OffersRepository _repository;
  final int loadId;

  void setPrice(String value) =>
      emit(state.copyWith(priceText: value, clearError: true));

  void setRemarks(String value) => emit(state.copyWith(remarks: value));

  Future<void> submit() async {
    if (state.isSubmitting || !state.canSubmit) return;
    final price = num.tryParse(state.priceText.trim());
    if (price == null || price <= 0) {
      emit(state.copyWith(
          status: MakeOfferStatus.failure, errorMessage: 'Enter a valid price'));
      return;
    }
    emit(state.copyWith(status: MakeOfferStatus.submitting, clearError: true));
    final result = await _repository.makeOffer(
      loadId: loadId,
      body: state.remarks.trim(),
      price: price,
    );
    switch (result) {
      case Success(value: final offer):
        emit(state.copyWith(status: MakeOfferStatus.success, created: offer));
      case Err(failure: final f):
        emit(state.copyWith(
          status: MakeOfferStatus.failure,
          errorMessage: f.message,
          fieldErrors: _flatten(f),
        ));
    }
  }

  static Map<String, String> _flatten(Failure f) {
    final raw = f is ValidationFailure ? f.fieldErrors : null;
    if (raw == null) return const {};
    return {
      for (final e in raw.entries)
        if (e.value.isNotEmpty) e.key: e.value.first,
    };
  }
}
