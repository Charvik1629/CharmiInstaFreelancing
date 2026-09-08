part of 'wallet_cubit.dart';

enum WalletStatus { initial, loading, loaded, error }

class WalletState extends Equatable {
  const WalletState({
    this.status = WalletStatus.initial,
    this.wallet,
    this.packages = const [],
    this.toppingUp = false,
    this.errorMessage,
  });

  final WalletStatus status;
  final Wallet? wallet;
  final List<CreditPackage> packages;
  final bool toppingUp;
  final String? errorMessage;

  WalletState copyWith({
    WalletStatus? status,
    Wallet? wallet,
    List<CreditPackage>? packages,
    bool? toppingUp,
    String? errorMessage,
  }) {
    return WalletState(
      status: status ?? this.status,
      wallet: wallet ?? this.wallet,
      packages: packages ?? this.packages,
      toppingUp: toppingUp ?? this.toppingUp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, wallet, packages, toppingUp, errorMessage];
}
