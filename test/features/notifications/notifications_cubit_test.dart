import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/notifications/domain/entities/app_notification.dart';
import 'package:charmi_insta_freelancing/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:charmi_insta_freelancing/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

AppNotification _n(int id, {bool read = false, String type = 'offer'}) =>
    AppNotification(id: id, type: type, title: 'N$id', read: read);

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  test('AppNotification.fromJson reads read/is_read + body/message', () {
    final a = AppNotification.fromJson(const {
      'id': 1,
      'type': 'approval',
      'title': 'Approved',
      'message': 'Welcome',
      'is_read': true,
    });
    expect(a.read, isTrue);
    expect(a.body, 'Welcome');
    expect(a.type, 'approval');
  });

  test('load emits loaded with items', () async {
    when(() => repo.getNotifications(page: any(named: 'page')))
        .thenAnswer((_) async => Success([_n(1), _n(2, read: true)]));
    final cubit = NotificationsCubit(repo);
    await cubit.load();
    expect(cubit.state.status, NotifStatus.loaded);
    expect(cubit.state.hasUnread, isTrue);
  });

  test('empty list emits empty', () async {
    when(() => repo.getNotifications(page: any(named: 'page')))
        .thenAnswer((_) async => const Success([]));
    final cubit = NotificationsCubit(repo);
    await cubit.load();
    expect(cubit.state.status, NotifStatus.empty);
  });

  test('404 degrades to gated (not error)', () async {
    when(() => repo.getNotifications(page: any(named: 'page')))
        .thenAnswer((_) async => const Err(NotFoundFailure()));
    final cubit = NotificationsCubit(repo);
    await cubit.load();
    expect(cubit.state.status, NotifStatus.gated);
  });

  test('other failure is an error', () async {
    when(() => repo.getNotifications(page: any(named: 'page')))
        .thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = NotificationsCubit(repo);
    await cubit.load();
    expect(cubit.state.status, NotifStatus.error);
  });

  test('markAllRead flips all to read', () async {
    when(() => repo.getNotifications(page: any(named: 'page')))
        .thenAnswer((_) async => Success([_n(1), _n(2)]));
    when(repo.markAllRead).thenAnswer((_) async => const Success(null));
    final cubit = NotificationsCubit(repo);
    await cubit.load();
    await cubit.markAllRead();
    expect(cubit.state.hasUnread, isFalse);
    verify(repo.markAllRead).called(1);
  });
}
