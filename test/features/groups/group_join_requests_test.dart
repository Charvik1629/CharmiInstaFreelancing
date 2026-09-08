import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/groups/domain/entities/group.dart';
import 'package:charmi_insta_freelancing/features/groups/domain/entities/group_join_request.dart';
import 'package:charmi_insta_freelancing/features/groups/domain/repositories/groups_repository.dart';
import 'package:charmi_insta_freelancing/features/groups/presentation/cubit/group_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements GroupsRepository {}

const _group = Group(id: 1, name: 'West Zone', memberCount: 3);
const _member = GroupMember(id: 9, name: 'Dave', role: 'member');
const _req = GroupJoinRequest(
  id: 7,
  status: 'pending',
  user: User(id: 4, name: 'Carol', roles: ['user']),
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(() => repo.getGroup(1)).thenAnswer((_) async => const Success(_group));
    when(() => repo.getMembers(1))
        .thenAnswer((_) async => const Success([_member]));
    when(() => repo.getJoinRequests(1))
        .thenAnswer((_) async => const Success([_req]));
  });

  test('load as manager fetches join requests', () async {
    final cubit = GroupDetailCubit(repo, 1);
    await cubit.load(isManager: true);
    expect(cubit.state.status, DetailStatus.loaded);
    expect(cubit.state.isManager, isTrue);
    expect(cubit.state.joinRequests, const [_req]);
  });

  test('load as non-manager does not fetch join requests', () async {
    final cubit = GroupDetailCubit(repo, 1);
    await cubit.load(isManager: false);
    expect(cubit.state.joinRequests, isEmpty);
    verifyNever(() => repo.getJoinRequests(any()));
  });

  test('approveRequest drops the row and reloads', () async {
    when(() => repo.approveJoinRequest(1, 7))
        .thenAnswer((_) async => const Success(null));
    // After approval the queue is empty on reload.
    final cubit = GroupDetailCubit(repo, 1);
    await cubit.load(isManager: true);
    when(() => repo.getJoinRequests(1))
        .thenAnswer((_) async => const Success([]));

    final ok = await cubit.approveRequest(_req);
    expect(ok, isTrue);
    expect(cubit.state.joinRequests, isEmpty);
    expect(cubit.state.actingOnId, isNull);
    verify(() => repo.approveJoinRequest(1, 7)).called(1);
  });

  test('declineRequest calls the decline endpoint', () async {
    when(() => repo.declineJoinRequest(1, 7))
        .thenAnswer((_) async => const Success(null));
    final cubit = GroupDetailCubit(repo, 1);
    await cubit.load(isManager: true);
    when(() => repo.getJoinRequests(1))
        .thenAnswer((_) async => const Success([]));

    final ok = await cubit.declineRequest(_req);
    expect(ok, isTrue);
    verify(() => repo.declineJoinRequest(1, 7)).called(1);
  });

  test('requestJoin reloads on success', () async {
    when(() => repo.requestJoin(1))
        .thenAnswer((_) async => const Success(null));
    final cubit = GroupDetailCubit(repo, 1);
    await cubit.load(isManager: false);
    final ok = await cubit.requestJoin();
    expect(ok, isTrue);
    verify(() => repo.requestJoin(1)).called(1);
  });

  test('leave surfaces failure message', () async {
    when(() => repo.leave(1))
        .thenAnswer((_) async => const Err(ServerFailure('nope', statusCode: 500)));
    final cubit = GroupDetailCubit(repo, 1);
    await cubit.load(isManager: false);
    final ok = await cubit.leave();
    expect(ok, isFalse);
    expect(cubit.state.errorMessage, 'nope');
  });

  test('removeMember drops the member row', () async {
    when(() => repo.removeMember(1, 9))
        .thenAnswer((_) async => const Success(null));
    final cubit = GroupDetailCubit(repo, 1);
    await cubit.load(isManager: true);
    final ok = await cubit.removeMember(_member);
    expect(ok, isTrue);
    expect(cubit.state.members, isEmpty);
  });
}
