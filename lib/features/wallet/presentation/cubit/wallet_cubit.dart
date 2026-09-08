import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';

part 'wallet_state.dart';

/// Loads the wallet summary + purchasable packages for the Wallet screen.
class WalletCubit extends Cubit<WalletState> {
  WalletCubit(this._repository) : super(const WalletState());

  final WalletRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: WalletStatus.loading));
    final walletResult = await _repository.getWallet();
    if (walletResult case Err(failure: final f)) {
      emit(state.copyWith(status: WalletStatus.error, errorMessage: f.message));
      return;
    }
    // Packages are secondary — a failure there just leaves the list empty.
    final packagesResult = await _repository.getPackages();
    emit(state.copyWith(
      status: WalletStatus.loaded,
      wallet: (walletResult as Success<Wallet>).value,
      packages: packagesResult.valueOrNull ?? const [],
    ));
  }

  Future<void> refresh() => load();

  /// Adds demo credits (dev/demo builds), then reloads the wallet. Returns the
  /// new balance, or null on failure.
  Future<int?> demoTopup() async {
    if (state.toppingUp) return null;
    emit(state.copyWith(toppingUp: true));
    final result = await _repository.demoTopup();
    switch (result) {
      case Success(value: final balance):
        await load();
        emit(state.copyWith(toppingUp: false));
        return balance;
      case Err(failure: final f):
        emit(state.copyWith(toppingUp: false, errorMessage: f.message));
        return null;
    }
  }
}
