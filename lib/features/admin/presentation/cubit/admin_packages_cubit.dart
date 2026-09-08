import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/wallet_package.dart';
import '../../domain/repositories/admin_wallet_repository.dart';

part 'admin_packages_state.dart';

/// Admin management of purchasable credit packages: list (incl. inactive),
/// create, update, delete.
class AdminPackagesCubit extends Cubit<AdminPackagesState> {
  AdminPackagesCubit(this._repository) : super(const AdminPackagesState());

  final AdminWalletRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: PackagesStatus.loading));
    final result = await _repository.getPackages();
    switch (result) {
      case Success(value: final list):
        final sorted = [...list]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        emit(state.copyWith(
          status: sorted.isEmpty
              ? PackagesStatus.empty
              : PackagesStatus.loaded,
          packages: sorted,
        ));
      case Err(failure: final f):
        emit(state.copyWith(
            status: PackagesStatus.error, errorMessage: f.message));
    }
  }

  Future<void> refresh() => load();

  Future<bool> createPackage({
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  }) async {
    final result = await _repository.createPackage(
      name: name,
      credits: credits,
      amountPaise: amountPaise,
      isActive: isActive,
      sortOrder: sortOrder,
    );
    if (result case Success(value: final pkg)) {
      final list = [...state.packages, pkg]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(packages: list, status: PackagesStatus.loaded));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<bool> updatePackage({
    required int id,
    required String name,
    required int credits,
    required int amountPaise,
    required bool isActive,
    required int sortOrder,
  }) async {
    final result = await _repository.updatePackage(
      id: id,
      name: name,
      credits: credits,
      amountPaise: amountPaise,
      isActive: isActive,
      sortOrder: sortOrder,
    );
    if (result case Success(value: final pkg)) {
      final list = state.packages.map((p) => p.id == id ? pkg : p).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      emit(state.copyWith(packages: list));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }

  Future<bool> deletePackage(int id) async {
    final result = await _repository.deletePackage(id);
    if (result.isSuccess) {
      final list = state.packages.where((p) => p.id != id).toList();
      emit(state.copyWith(
        packages: list,
        status: list.isEmpty ? PackagesStatus.empty : PackagesStatus.loaded,
      ));
      return true;
    }
    emit(state.copyWith(errorMessage: result.failureOrNull?.message));
    return false;
  }
}
