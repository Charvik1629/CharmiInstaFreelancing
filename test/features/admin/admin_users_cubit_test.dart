import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/network/api_response.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/admin/domain/entities/user_approval.dart';
import 'package:charmi_insta_freelancing/features/admin/domain/repositories/admin_repository.dart';
import 'package:charmi_insta_freelancing/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAdminRepo extends Mock implements AdminRepository {}

PaginatedResponse<User> _page(List<User> users) => PaginatedResponse(
      items: users,
      meta: const PaginationMeta(currentPage: 1),
    );

void main() {
  late _MockAdminRepo repo;

  const jane = User(
    id: 5,
    name: 'Jane Doe',
    businessName: 'Doe Transport',
    approvalStatus: 'pending',
    roles: ['user'],
  );
  const bob = User(id: 6, name: 'Bob', approvalStatus: 'pending', roles: ['user']);

  setUpAll(() => registerFallbackValue(UserApprovalStatus.pending));
  setUp(() => repo = _MockAdminRepo());

  test('load emits loaded with the pending queue', () async {
    when(() => repo.getUsers(
        status: UserApprovalStatus.pending,
        page: any(named: 'page'))).thenAnswer((_) async => Success(_page([jane, bob])));

    final cubit = AdminUsersCubit(repo);
    await cubit.load();

    expect(cubit.state.status, UsersStatus.loaded);
    expect(cubit.state.users, [jane, bob]);
  });

  test('load emits empty when there are no pending accounts', () async {
    when(() => repo.getUsers(
            status: any(named: 'status'), page: any(named: 'page')))
        .thenAnswer((_) async => Success(_page(const [])));

    final cubit = AdminUsersCubit(repo);
    await cubit.load();

    expect(cubit.state.status, UsersStatus.empty);
  });

  test('load surfaces an error', () async {
    when(() => repo.getUsers(
            status: any(named: 'status'), page: any(named: 'page')))
        .thenAnswer((_) async => const Err(NetworkFailure()));

    final cubit = AdminUsersCubit(repo);
    await cubit.load();

    expect(cubit.state.status, UsersStatus.error);
  });

  test('approve removes the row from the pending list', () async {
    when(() => repo.getUsers(
            status: any(named: 'status'), page: any(named: 'page')))
        .thenAnswer((_) async => Success(_page([jane, bob])));
    when(() => repo.approveUser(5))
        .thenAnswer((_) async => Success(jane.copyWith(approvalStatus: 'approved')));

    final cubit = AdminUsersCubit(repo);
    await cubit.load();
    final ok = await cubit.approve(jane);

    expect(ok, isTrue);
    expect(cubit.state.users.map((u) => u.id), [6]);
    expect(cubit.state.actingOnId, isNull);
  });

  test('reject removes the row and reports failure without dropping it', () async {
    when(() => repo.getUsers(
            status: any(named: 'status'), page: any(named: 'page')))
        .thenAnswer((_) async => Success(_page([jane, bob])));
    when(() => repo.rejectUser(6))
        .thenAnswer((_) async => const Err(ServerFailure('boom', statusCode: 500)));

    final cubit = AdminUsersCubit(repo);
    await cubit.load();
    final ok = await cubit.reject(bob);

    expect(ok, isFalse);
    expect(cubit.state.users.map((u) => u.id), [5, 6]); // unchanged
    expect(cubit.state.errorMessage, 'boom');
  });

  test('setFilter reloads for the new status', () async {
    when(() => repo.getUsers(
            status: UserApprovalStatus.pending, page: any(named: 'page')))
        .thenAnswer((_) async => Success(_page([jane])));
    when(() => repo.getUsers(
            status: UserApprovalStatus.approved, page: any(named: 'page')))
        .thenAnswer((_) async => Success(_page([bob.copyWith(approvalStatus: 'approved')])));

    final cubit = AdminUsersCubit(repo);
    await cubit.load();
    await cubit.setFilter(UserApprovalStatus.approved);

    expect(cubit.state.filter, UserApprovalStatus.approved);
    expect(cubit.state.users.map((u) => u.id), [6]);
  });
}
