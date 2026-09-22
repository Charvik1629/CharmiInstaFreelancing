import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/chat_message.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/conversation.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/repositories/chat_repository.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/cubit/chat_list_cubit.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/cubit/conversation_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockChatRepo extends Mock implements ChatRepository {}

Conversation _conv(int id, ConversationType type, {DateTime? at, int unread = 0}) =>
    Conversation(id: id, type: type, title: 'C$id', lastMessageAt: at, unreadCount: unread);

ChatMessage _msg(int id, {int? sender}) =>
    ChatMessage(id: id, body: 'm$id', senderId: sender);

void main() {
  setUpAll(() => registerFallbackValue(ConversationType.direct));

  group('Conversation parsing', () {
    test('direct chat json', () {
      final c = Conversation.fromChatJson({
        'conversation_id': 12,
        'type': 'direct',
        'title': 'Bob User',
        'peer': {'id': 3, 'name': 'Bob', 'avatar_url': '/a.jpg'},
        'unread_count': 2,
        'can_chat': true,
        'last_message': {'body': 'hey', 'created_at': '2026-08-25T11:00:00+00:00'},
      });
      expect(c.id, 12);
      expect(c.type, ConversationType.direct);
      expect(c.avatarUrl, '/a.jpg');
      expect(c.unreadCount, 2);
      expect(c.lastMessage, 'hey');
      expect(c.hasUnread, isTrue);
    });

    test('group type and image-only preview', () {
      final c = Conversation.fromChatJson({
        'conversation_id': 5,
        'type': 'group',
        'title': 'Drivers',
        'last_message': {
          'body': null,
          'attachments': [{'kind': 'image', 'url': '/x.jpg'}],
        },
      });
      expect(c.type, ConversationType.group);
      expect(c.lastMessage, '📷 Photo');
    });

    test('broadcast json maps recipients into subtitle', () {
      final c = Conversation.fromBroadcastJson({
        'id': 1,
        'name': 'Client Updates',
        'recipient_count': 2,
        'last_message': {'body': 'Pickup 6am', 'created_at': '2026-08-26T10:00:00+00:00'},
      });
      expect(c.type, ConversationType.broadcast);
      expect(c.title, 'Client Updates');
      expect(c.subtitle, '2 recipients');
      expect(c.isBroadcast, isTrue);
    });
  });

  group('ChatMessage parsing', () {
    test('extracts sender and image attachment; isMine', () {
      final m = ChatMessage.fromJson({
        'id': 51,
        'body': null,
        'sender': {'id': 2, 'name': 'Alice'},
        'attachments': [{'kind': 'image', 'url': '/media/x.jpg'}],
        'created_at': '2026-08-25T08:05:00+00:00',
      });
      expect(m.senderId, 2);
      expect(m.hasImage, isTrue);
      expect(m.imageUrl, '/media/x.jpg');
      expect(m.isMine(2), isTrue);
      expect(m.isMine(9), isFalse);
    });

    test('captures a non-image (document/video/audio) attachment as a chip', () {
      final doc = ChatMessage.fromJson({
        'id': 60,
        'body': null,
        'sender': {'id': 3, 'name': 'Bob'},
        'attachments': [
          {'kind': 'file', 'url': '/media/a/spec.pdf', 'original_name': 'spec.pdf'}
        ],
      });
      expect(doc.hasImage, isFalse);
      expect(doc.hasFileAttachment, isTrue);
      expect(doc.attachmentKind, 'file');
      expect(doc.attachmentName, 'spec.pdf');

      final audio = ChatMessage.fromJson({
        'id': 61,
        'attachments': [
          {'kind': 'audio', 'url': '/media/a/voice.webm', 'original_name': 'voice.webm'}
        ],
      });
      expect(audio.hasFileAttachment, isTrue);
      expect(audio.attachmentKind, 'audio');
    });
  });

  group('ChatListCubit', () {
    late _MockChatRepo repo;
    setUp(() {
      repo = _MockChatRepo();
      // Labels are fetched on load(); default to none unless a test overrides it.
      when(() => repo.getLabels()).thenAnswer((_) async => const Success([]));
      // "All" merges questions too; default to none unless a test overrides it.
      when(() => repo.getQuestions()).thenAnswer((_) async => const Success([]));
    });

    test('all merges chats + broadcasts, newest first', () async {
      final t1 = DateTime(2026, 8, 20);
      final t2 = DateTime(2026, 8, 25);
      final t3 = DateTime(2026, 8, 28);
      when(() => repo.getChats()).thenAnswer((_) async => Success([
            _conv(1, ConversationType.direct, at: t1),
            _conv(2, ConversationType.group, at: t3),
          ]));
      when(() => repo.getBroadcasts()).thenAnswer(
          (_) async => Success([_conv(3, ConversationType.broadcast, at: t2)]));

      final cubit = ChatListCubit(repo);
      await cubit.load();

      expect(cubit.state.status, ChatListStatus.loaded);
      expect(cubit.state.conversations.map((c) => c.id).toList(), [2, 3, 1]);
    });

    test('direct filter keeps only direct chats', () async {
      when(() => repo.getChats()).thenAnswer((_) async => Success([
            _conv(1, ConversationType.direct),
            _conv(2, ConversationType.group),
          ]));
      final cubit = ChatListCubit(repo);
      await cubit.setFilter(ChatFilter.direct);
      expect(cubit.state.conversations.map((c) => c.id), [1]);
    });

    test('broadcasts filter uses the broadcasts endpoint', () async {
      when(() => repo.getBroadcasts()).thenAnswer(
          (_) async => Success([_conv(9, ConversationType.broadcast)]));
      final cubit = ChatListCubit(repo);
      await cubit.setFilter(ChatFilter.broadcasts);
      expect(cubit.state.conversations.single.id, 9);
      verifyNever(() => repo.getChats());
    });

    test('questions filter loads the Q&A inbox only', () async {
      when(() => repo.getQuestions()).thenAnswer(
          (_) async => Success([_conv(9, ConversationType.direct)]));
      final cubit = ChatListCubit(repo);
      await cubit.setFilter(ChatFilter.questions);
      expect(cubit.state.conversations.single.id, 9);
      verifyNever(() => repo.getChats());
      verifyNever(() => repo.getBroadcasts());
    });

    test('empty result → empty status', () async {
      when(() => repo.getChats()).thenAnswer((_) async => const Success([]));
      when(() => repo.getBroadcasts()).thenAnswer((_) async => const Success([]));
      final cubit = ChatListCubit(repo);
      await cubit.load();
      expect(cubit.state.status, ChatListStatus.empty);
    });

    test('all: error only when every source fails', () async {
      when(() => repo.getChats())
          .thenAnswer((_) async => const Err(NetworkFailure()));
      when(() => repo.getQuestions())
          .thenAnswer((_) async => const Err(NetworkFailure()));
      when(() => repo.getBroadcasts())
          .thenAnswer((_) async => const Err(NetworkFailure()));
      final cubit = ChatListCubit(repo);
      await cubit.load();
      expect(cubit.state.status, ChatListStatus.error);
    });
  });

  group('ConversationCubit', () {
    late _MockChatRepo repo;
    final direct = _conv(12, ConversationType.direct);
    final broadcast = _conv(1, ConversationType.broadcast);

    setUp(() => repo = _MockChatRepo());

    test('load fills messages and marks a direct thread read', () async {
      when(() => repo.getMessages(id: 12, type: ConversationType.direct, beforeId: null))
          .thenAnswer((_) async => Success(MessagePage(items: [_msg(1), _msg(2)])));
      when(() => repo.markRead(12)).thenAnswer((_) async => const Success(null));

      final cubit = ConversationCubit(repo, direct, meId: 2);
      await cubit.load();

      expect(cubit.state.status, ThreadStatus.loaded);
      expect(cubit.state.messages.length, 2);
      verify(() => repo.markRead(12)).called(1);
    });

    test('broadcast thread is not marked read', () async {
      when(() => repo.getMessages(id: 1, type: ConversationType.broadcast, beforeId: null))
          .thenAnswer((_) async => Success(MessagePage(items: [_msg(1)])));
      final cubit = ConversationCubit(repo, broadcast);
      await cubit.load();
      verifyNever(() => repo.markRead(any()));
    });

    test('send appends the created message', () async {
      when(() => repo.getMessages(id: 12, type: ConversationType.direct, beforeId: null))
          .thenAnswer((_) async => Success(MessagePage(items: [_msg(1)])));
      when(() => repo.markRead(12)).thenAnswer((_) async => const Success(null));
      when(() => repo.sendMessage(id: 12, type: ConversationType.direct, body: 'hello'))
          .thenAnswer((_) async => Success(_msg(2, sender: 2)));

      final cubit = ConversationCubit(repo, direct, meId: 2);
      await cubit.load();
      await cubit.send('  hello  ');

      expect(cubit.state.messages.map((m) => m.id), [1, 2]);
      expect(cubit.state.isSending, isFalse);
    });

    test('sendImage forwards the image path and appends the message', () async {
      when(() => repo.getMessages(id: 12, type: ConversationType.direct, beforeId: null))
          .thenAnswer((_) async => Success(MessagePage(items: [_msg(1)])));
      when(() => repo.markRead(12)).thenAnswer((_) async => const Success(null));
      when(() => repo.sendMessage(
              id: 12,
              type: ConversationType.direct,
              body: '',
              attachmentPaths: const ['/tmp/pic.jpg']))
          .thenAnswer((_) async => Success(_msg(3, sender: 2)));

      final cubit = ConversationCubit(repo, direct, meId: 2);
      await cubit.load();
      await cubit.sendImage('/tmp/pic.jpg');

      expect(cubit.state.messages.map((m) => m.id), [1, 3]);
      verify(() => repo.sendMessage(
          id: 12,
          type: ConversationType.direct,
          body: '',
          attachmentPaths: const ['/tmp/pic.jpg'])).called(1);
    });

    test('loadMore prepends older messages', () async {
      when(() => repo.getMessages(id: 12, type: ConversationType.direct, beforeId: null))
          .thenAnswer((_) async => Success(
              MessagePage(items: [_msg(10)], hasMore: true, nextBeforeId: 10)));
      when(() => repo.markRead(12)).thenAnswer((_) async => const Success(null));
      when(() => repo.getMessages(id: 12, type: ConversationType.direct, beforeId: 10))
          .thenAnswer((_) async => Success(MessagePage(items: [_msg(8), _msg(9)])));

      final cubit = ConversationCubit(repo, direct, meId: 2);
      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.messages.map((m) => m.id), [8, 9, 10]);
    });

    test('cannot send when canChat is false', () async {
      final locked = Conversation(
          id: 3, type: ConversationType.direct, title: 'x', canChat: false);
      final cubit = ConversationCubit(repo, locked, meId: 2);
      await cubit.send('hi');
      verifyNever(() => repo.sendMessage(
          id: any(named: 'id'), type: any(named: 'type'), body: any(named: 'body')));
    });
  });
}
