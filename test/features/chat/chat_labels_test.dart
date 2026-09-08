import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/chat_label.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/conversation.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/repositories/chat_repository.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/cubit/chat_labels_cubit.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements ChatRepository {}

const _work = ChatLabel(id: 1, name: 'Work', color: '#25d366');

Conversation _conv(int id, {List<ChatLabel> labels = const []}) => Conversation(
      id: id,
      type: ConversationType.direct,
      title: 'Chat $id',
      lastMessageAt: DateTime(2026, 8, id),
      labels: labels,
    );

void main() {
  setUpAll(() => registerFallbackValue(ConversationType.direct));

  group('ChatLabel.colorValue', () {
    test('parses hex; falls back on invalid', () {
      expect(_work.colorValue(Colors.black).toARGB32(), 0xFF25D366);
      const bad = ChatLabel(id: 2, name: 'x', color: 'nope');
      expect(bad.colorValue(Colors.black), Colors.black);
    });
  });

  group('ChatLabelsCubit', () {
    late _MockRepo repo;
    setUp(() => repo = _MockRepo());

    test('load sorts by sort order', () async {
      when(repo.getLabels).thenAnswer((_) async => const Success([
            ChatLabel(id: 2, name: 'B', sortOrder: 2),
            ChatLabel(id: 1, name: 'A', sortOrder: 1),
          ]));
      final cubit = ChatLabelsCubit(repo);
      await cubit.load();
      expect(cubit.state.status, LabelsStatus.loaded);
      expect(cubit.state.labels.map((l) => l.id), [1, 2]);
    });

    test('create appends; delete removes', () async {
      when(repo.getLabels).thenAnswer((_) async => const Success([_work]));
      when(() => repo.createLabel(
              name: any(named: 'name'),
              color: any(named: 'color'),
              sortOrder: any(named: 'sortOrder')))
          .thenAnswer((_) async =>
              const Success(ChatLabel(id: 2, name: 'Clients', sortOrder: 1)));
      when(() => repo.deleteLabel(1))
          .thenAnswer((_) async => const Success(null));

      final cubit = ChatLabelsCubit(repo);
      await cubit.load();
      expect(await cubit.createLabel(name: 'Clients', sortOrder: 1), isTrue);
      expect(cubit.state.labels.map((l) => l.id), [1, 2]);
      expect(await cubit.deleteLabel(1), isTrue);
      expect(cubit.state.labels.map((l) => l.id), [2]);
    });
  });

  group('ChatListCubit labels', () {
    late _MockRepo repo;
    setUp(() {
      repo = _MockRepo();
      when(repo.getLabels).thenAnswer((_) async => const Success([_work]));
      when(repo.getChats).thenAnswer((_) async => Success([
            _conv(1, labels: const [_work]),
            _conv(2),
          ]));
      when(repo.getBroadcasts).thenAnswer((_) async => const Success([]));
    });

    test('setLabelFilter filters client-side to that label', () async {
      final cubit = ChatListCubit(repo);
      await cubit.load();
      expect(cubit.state.conversations.length, 2);
      expect(cubit.state.labels, const [_work]);

      cubit.setLabelFilter(1);
      expect(cubit.state.conversations.map((c) => c.id), [1]);

      cubit.setLabelFilter(null);
      expect(cubit.state.conversations.length, 2);
    });

    test('toggleLabel attaches when the label is absent, then reloads', () async {
      when(() => repo.attachLabel(2, 1))
          .thenAnswer((_) async => const Success(null));
      final cubit = ChatListCubit(repo);
      await cubit.load();

      final ok = await cubit.toggleLabel(_conv(2), _work);
      expect(ok, isTrue);
      verify(() => repo.attachLabel(2, 1)).called(1);
      verifyNever(() => repo.detachLabel(any(), any()));
    });

    test('toggleLabel detaches when the label is present', () async {
      when(() => repo.detachLabel(1, 1))
          .thenAnswer((_) async => const Success(null));
      final cubit = ChatListCubit(repo);
      await cubit.load();

      final ok =
          await cubit.toggleLabel(_conv(1, labels: const [_work]), _work);
      expect(ok, isTrue);
      verify(() => repo.detachLabel(1, 1)).called(1);
    });

    test('toggleLabel surfaces failure', () async {
      when(() => repo.attachLabel(2, 1))
          .thenAnswer((_) async => const Err(ServerFailure('no', statusCode: 500)));
      final cubit = ChatListCubit(repo);
      await cubit.load();
      final ok = await cubit.toggleLabel(_conv(2), _work);
      expect(ok, isFalse);
      expect(cubit.state.errorMessage, 'no');
    });
  });
}
