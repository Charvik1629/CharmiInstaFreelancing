part of 'admin_packages_cubit.dart';

enum PackagesStatus { initial, loading, loaded, empty, error }

class AdminPackagesState extends Equatable {
  const AdminPackagesState({
    this.status = PackagesStatus.initial,
    this.packages = const [],
    this.errorMessage,
  });

  final PackagesStatus status;
  final List<WalletPackage> packages;
  final String? errorMessage;

  AdminPackagesState copyWith({
    PackagesStatus? status,
    List<WalletPackage>? packages,
    String? errorMessage,
  }) {
    return AdminPackagesState(
      status: status ?? this.status,
      packages: packages ?? this.packages,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, packages, errorMessage];
}
