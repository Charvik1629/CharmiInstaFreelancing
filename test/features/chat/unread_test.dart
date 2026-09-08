import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/unread_counts.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/repositories/chat_repository.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/cubit/unread_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ChatRepository {}

void main() {
  test('UnreadCounts.inbox = chats + questions; fromJson parses', () {
    final c = UnreadCounts.fromJson(
        const {'total': 5, 'chats': 2, 'questions': 1, 'offers': 2});
    expect(c.inbox, 3);
    expect(c.offers, 2);
  });

  group('UnreadCubit', () {
    late _MockRepo repo;
    setUp(() => repo = _MockRepo());

    test('refresh emits counts', () async {
      when(repo.getUnreadCounts).thenAnswer(
          (_) async => const Success(UnreadCounts(chats: 2, questions: 1, offers: 2)));
      final cubit = UnreadCubit(repo);
      await cubit.refresh();
      expect(cubit.state.inbox, 3);
    });

    test('refresh keeps last value on failure', () async {
      when(repo.getUnreadCounts)
          .thenAnswer((_) async => const Success(UnreadCounts(chats: 4)));
      final cubit = UnreadCubit(repo);
      await cubit.refresh();
      expect(cubit.state.chats, 4);

      when(repo.getUnreadCounts)
          .thenAnswer((_) async => const Err(NetworkFailure()));
      await cubit.refresh();
      expect(cubit.state.chats, 4); // unchanged
    });

    test('clearInbox zeroes chats/questions but keeps offers', () async {
      when(repo.getUnreadCounts).thenAnswer(
          (_) async => const Success(UnreadCounts(chats: 2, questions: 1, offers: 3)));
      final cubit = UnreadCubit(repo);
      await cubit.refresh();
      cubit.clearInbox();
      expect(cubit.state.inbox, 0);
      expect(cubit.state.offers, 3);
    });
  });
}
