import 'package:charmi_insta_freelancing/features/chat/presentation/widgets/message_reaction_badge.dart';

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/disappearing_settings.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/pages/disappearing_messages_page.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/widgets/chat_emoji_sheet.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/network/api_client.dart';
import 'package:charmi_insta_freelancing/core/realtime/socket_service.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/chat_message.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/conversation.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/entities/message_reaction.dart';
import 'package:charmi_insta_freelancing/features/chat/domain/repositories/chat_repository.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/cubit/conversation_cubit.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/pages/chat_image_editor_page.dart';
import 'package:charmi_insta_freelancing/features/chat/presentation/widgets/message_reply_widgets.dart';

class _Repository extends Mock implements ChatRepository {}

class _Adapter implements HttpClientAdapter {
  late RequestOptions request;
  String wire = '';
  Object response = {
    'data': <String, dynamic>{'id': 1, 'body': 'ok'},
  };
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    request = options;
    if (stream != null) {
      wire = utf8.decode(
        await stream.fold<List<int>>([], (a, b) => a..addAll(b)),
        allowMalformed: true,
      );
    }
    return ResponseBody.fromString(
      status == 204 ? '' : jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const conversation = Conversation(
    id: 2,
    type: ConversationType.direct,
    title: 'QA',
    isSelf: true,
  );
  const root = ChatMessage(
    id: 10,
    body: 'Original',
    senderId: 1,
    senderName: 'QA',
  );
  late _Repository repository;
  late ConversationCubit cubit;
  late _Adapter adapter;
  late ChatRemoteDataSourceImpl remote;
  setUp(() {
    repository = _Repository();
    when(() => repository.markRead(2))
        .thenAnswer((_) async => const Success(null));
    when(() => repository.getMessages(id: 2, type: ConversationType.direct))
        .thenAnswer((_) async => const Success(MessagePage(items: [root])));
    cubit = ConversationCubit(repository, conversation, meId: 1);
    adapter = _Adapter();
    remote = ChatRemoteDataSourceImpl(
      ApiClient(
        Dio(BaseOptions(baseUrl: 'https://test.invalid'))
          ..httpClientAdapter = adapter,
      ),
    );
  });
  tearDown(() async {
    await cubit.close();
  });

  test('reply ID survives JSON and actual multipart encoding', () async {
    await remote.sendMessage(
      id: 2,
      type: ConversationType.direct,
      body: 'reply',
      replyToMessageId: 10,
    );
    expect(adapter.request.data, {'body': 'reply', 'reply_to_message_id': 10});
    final dir = await Directory.systemTemp.createTemp('chat-payload-');
    try {
      final file = File('${dir.path}/qa.txt');
      await file.writeAsString('QA');
      await remote.sendMessage(
        id: 2,
        type: ConversationType.direct,
        body: 'caption',
        attachmentPaths: [file.path],
        replyToMessageId: 10,
      );
      expect(adapter.wire, contains('name="reply_to_message_id"\r\n\r\n10'));
      expect(adapter.wire, contains('name="attachments[]";'));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('reaction set and explicit removal use different verbs and preserve other reactions', () async {
    adapter.response = {
      'data': {
        'message_id': 10,
        'my_reaction': '👍🏽',
        'reactions': [
          {
            'emoji': '❤️',
            'count': 1,
            'users': [
              {'id': 9, 'name': 'Other'},
            ],
          },
          {
            'emoji': '👍🏽',
            'count': 1,
            'users': [
              {'id': 1, 'name': 'QA'},
            ],
          },
        ],
      },
    };
    final added = await remote.react(2, 10, '👍🏽');
    expect(adapter.request.method, 'PUT');
    expect(adapter.request.path, '/conversations/2/messages/10/reaction');
    expect(adapter.request.data, {'emoji': '👍🏽'});
    expect(added.reactions.length, 2);
    adapter.response = {
      'data': {
        'message_id': 10,
        'my_reaction': null,
        'reactions': [
          {
            'emoji': '❤️',
            'count': 1,
            'users': [
              {'id': 9, 'name': 'Other'},
            ],
          },
        ],
      },
    };
    final removed = await remote.react(2, 10, null);
    expect(adapter.request.method, 'DELETE');
    expect(removed.myReaction, isNull);
    expect(removed.reactions.single.users.single.id, 9);
  });

  test('delete scope is explicit and whole-chat 204 is accepted', () async {
    await remote.deleteMessage(2, 10, scope: MessageDeleteScope.me);
    expect(adapter.request.data, {'for': 'me'});
    await remote.deleteMessage(2, 10, scope: MessageDeleteScope.everyone);
    expect(adapter.request.data, {'for': 'everyone'});
    adapter.status = 204;
    await remote.deleteConversation(2);
    expect(adapter.request.path, '/conversations/2');
    expect(adapter.request.method, 'DELETE');
  });

  test('timer options come from server, enabling includes hours and off omits hours', () async {
    adapter.response = {
      'data': {
        'durations': [
          {'hours': 48, 'label': '2 days'},
        ],
      },
    };
    expect((await remote.getDisappearingOptions()).single.hours, 48);
    adapter.response = {
      'data': {
        'disappearing_messages': true,
        'disappearing_duration_hours': 48,
        'disappearing_duration_label': '2 days',
      },
    };
    final enabled = await remote.setDisappearing(2, enabled: true, hours: 48);
    expect(adapter.request.data, {'enabled': true, 'duration_hours': 48});
    expect(enabled.settings.hours, 48);
    await remote.setDisappearing(2, enabled: false, hours: 48);
    expect(adapter.request.data, {'enabled': false});
  });

  test('reply selection survives failed send and clears only after successful send', () async {
    await cubit.load();
    cubit.startReply(root);
    when(
      () => repository.sendMessage(
        id: 2,
        type: ConversationType.direct,
        body: 'reply',
        replyToMessageId: 10,
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await cubit.send('reply');
    expect(cubit.state.replyingTo?.id, 10);
    expect(cubit.state.errorMessage, isNotNull);
    when(
      () => repository.sendMessage(
        id: 2,
        type: ConversationType.direct,
        body: 'reply',
        replyToMessageId: 10,
      ),
    ).thenAnswer(
      (_) async => const Success(
        ChatMessage(id: 11, body: 'reply', replyToMessageId: 10),
      ),
    );
    await cubit.send('reply');
    expect(cubit.state.replyingTo, isNull);
    expect(cubit.state.messages.last.replyToMessageId, 10);
  });

  test(
    'a different reply chosen during an in-flight send is preserved',
    () async {
      await cubit.load();
      cubit.startReply(root);
      when(
        () => repository.sendMessage(
          id: 2,
          type: ConversationType.direct,
          body: 'reply',
          replyToMessageId: 10,
        ),
      ).thenAnswer((_) async {
        cubit.startReply(const ChatMessage(id: 12, body: 'Other'));
        return const Success(ChatMessage(id: 11, body: 'reply'));
      });
      await cubit.send('reply');
      expect(cubit.state.replyingTo?.id, 12);
    },
  );

  test('delete-for-everyone preserves tombstone; delete-for-me removes only its row', () async {
    await cubit.load();
    when(
      () => repository.deleteMessage(2, 10, scope: MessageDeleteScope.everyone),
    ).thenAnswer((_) async => const Success(null));
    await cubit.deleteMessage(10);
    expect(cubit.state.messages.single.isDeleted, isTrue);
    expect(cubit.state.messages.single.body, isNull);
    when(() => repository.deleteMessage(2, 10, scope: MessageDeleteScope.me))
        .thenAnswer((_) async => const Success(null));
    await cubit.deleteMessage(10, scope: MessageDeleteScope.me);
    expect(cubit.state.messages, isEmpty);
    expect(cubit.state.status, ThreadStatus.empty);
  });

  test('failed destructive action leaves the message intact', () async {
    await cubit.load();
    when(
      () => repository.deleteMessage(2, 10, scope: MessageDeleteScope.everyone),
    ).thenAnswer((_) async => const Err(ForbiddenFailure()));
    await cubit.deleteMessage(10);
    expect(cubit.state.messages.single, root);
  });

  test(
    'realtime reaction infers mine from users and clears only mine',
    () async {
      await cubit.load();
      cubit.applyChatChange(
        const ChatChangeEvent(
          kind: 'message:reaction',
          conversationId: 2,
          data: {
            'message_id': 10,
            'reactions': [
              {
                'emoji': '👍',
                'count': 2,
                'users': [
                  {'id': 1, 'name': 'QA'},
                  {'id': 9, 'name': 'Other'},
                ],
              },
            ],
          },
        ),
      );
      expect(cubit.state.messages.single.myReaction, '👍');
      cubit.applyChatChange(
        const ChatChangeEvent(
          kind: 'message:reaction',
          conversationId: 2,
          data: {
            'message_id': 10,
            'reactions': [
              {
                'emoji': '👍',
                'count': 1,
                'users': [
                  {'id': 9, 'name': 'Other'},
                ],
              },
            ],
          },
        ),
      );
      expect(cubit.state.messages.single.myReaction, isNull);
      expect(cubit.state.messages.single.reactions.single.count, 1);
    },
  );

  test('cross-conversation mutation ignored; deleted quote snapshot loses original text', () async {
    when(() => repository.getMessages(id: 2, type: ConversationType.direct))
        .thenAnswer(
          (_) async => const Success(
            MessagePage(
              items: [
                root,
                ChatMessage(
                  id: 11,
                  body: 'reply',
                  replyToMessageId: 10,
                  replyTo: MessageReply(id: 10, body: 'Original'),
                ),
              ],
            ),
          ),
        );
    await cubit.load();
    cubit.applyChatChange(
      const ChatChangeEvent(
        kind: 'message:hidden',
        conversationId: 999,
        data: {'message_id': 10},
      ),
    );
    expect(cubit.state.messages.length, 2);
    cubit.applyChatChange(
      const ChatChangeEvent(
        kind: 'message:deleted',
        conversationId: 2,
        data: {'id': 10, 'body': null, 'is_deleted': true, 'type': 'system'},
      ),
    );
    expect(cubit.state.messages.length, 2);
    expect(
      cubit.state.messages.last.replyTo!.preview,
      'This message was deleted',
    );
  });

  test(
    'expiry hides content locally but kept messages remain readable',
    () async {
      final expiry = DateTime.now().subtract(const Duration(minutes: 1));
      when(
        () => repository.getMessages(id: 2, type: ConversationType.direct),
      ).thenAnswer(
        (_) async => Success(
          MessagePage(
            items: [
              ChatMessage(id: 10, body: 'Expired secret', expiresAt: expiry),
              ChatMessage(
                id: 11,
                body: 'Kept',
                expiresAt: expiry,
                isKept: true,
              ),
            ],
          ),
        ),
      );
      await cubit.load();
      cubit.expireDueMessages();
      expect(cubit.state.messages.first.isDeleted, isTrue);
      expect(cubit.state.messages.first.body, isNull);
      expect(cubit.state.messages.last.body, 'Kept');
    },
  );

  test('socket wrapper parsing keeps conversation and message identities', () {
    final event = ChatChangeEvent.fromPayload('message:updated', {
      'conversation_id': 2,
      'data': {'id': 10, 'body': 'Edited'},
    })!;
    expect(event.conversationId, 2);
    expect(event.messageId, 10);
    expect(
      ChatChangeEvent.fromPayload('conversation:updated', {
        'data': {
          'conversation': {'id': 2},
        },
      })!.conversationId,
      2,
    );
  });

  test('pixel transforms crop the intended region, rotate dimensions and flip colors', () {
    final image = img.Image(width: 4, height: 2);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    for (var y = 0; y < 2; y++) {
      for (var x = 2; x < 4; x++) {
        image.setPixelRgb(x, y, 0, 0, 255);
      }
    }
    final bytes = Uint8List.fromList(img.encodePng(image));
    final cropped = img.decodePng(
      transformChatImage({
        'bytes': bytes,
        'operation': 'crop',
        'rect': <double>[.5, 0, .5, 1],
      }),
    )!;
    expect(cropped.width, 2);
    expect(cropped.height, 2);
    expect(cropped.getPixel(0, 0).b, 255);
    final rotated = img.decodePng(
      transformChatImage({'bytes': bytes, 'operation': 'rotate'}),
    )!;
    expect([rotated.width, rotated.height], [2, 4]);
    final flipped = img.decodePng(
      transformChatImage({'bytes': bytes, 'operation': 'flip'}),
    )!;
    expect(flipped.getPixel(0, 0).b, 255);
    expect(flipped.getPixel(3, 0).r, 255);
    expect(img.decodePng(bytes)!.getPixel(0, 0).r, 255);
  });

  test(
    'late send result after leaving a thread does not emit on a closed cubit',
    () async {
      final response = Completer<Result<ChatMessage>>();
      when(
        () => repository.sendMessage(
          id: 2,
          type: ConversationType.direct,
          body: 'late',
        ),
      ).thenAnswer((_) => response.future);
      final sending = cubit.send('late');
      await cubit.close();
      response.complete(const Success(ChatMessage(id: 99, body: 'late')));
      await expectLater(sending, completes);
    },
  );

  test('whole-chat deletion clears only on success', () async {
    await cubit.load();
    when(() => repository.deleteConversation(2))
        .thenAnswer((_) async => const Err(NetworkFailure()));
    await cubit.deleteChat();
    expect(cubit.state.chatDeleted, isFalse);
    expect(cubit.state.messages.single.id, 10);
    when(() => repository.deleteConversation(2))
        .thenAnswer((_) async => const Success(null));
    await cubit.deleteChat();
    expect(cubit.state.chatDeleted, isTrue);
    expect(cubit.state.messages, isEmpty);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'timer page uses server durations in $brightness and submits chosen hours',
      (tester) async {
        when(() => repository.getDisappearingOptions()).thenAnswer(
          (_) async => const Success([DisappearingDuration(48, '2 days')]),
        );
        int? submittedHours;
        bool? submittedEnabled;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  child: const Text('Open'),
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute(
                      builder: (_) => DisappearingMessagesPage(
                        repository: repository,
                        initial: const DisappearingSettings(),
                        onApply: ({required bool enabled, int? hours}) async {
                          submittedEnabled = enabled;
                          submittedHours = hours;
                          return const Success(
                            DisappearingUpdate(
                              DisappearingSettings(
                                enabled: true,
                                hours: 48,
                                label: '2 days',
                              ),
                              null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('2 days'), findsOneWidget);
        expect(find.text('7 days'), findsNothing);
        await tester.tap(find.text('2 days'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Update timer'));
        await tester.pumpAndSettle();
        expect(submittedHours, 48);
        expect(submittedEnabled, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'timer option failure can retry without inventing allowed durations',
    (tester) async {
      var calls = 0;
      when(() => repository.getDisappearingOptions()).thenAnswer(
        (_) async => ++calls == 1
            ? const Err(NetworkFailure())
            : const Success([DisappearingDuration(24, '24 hours')]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DisappearingMessagesPage(
            repository: repository,
            initial: const DisappearingSettings(),
            onApply: ({required bool enabled, int? hours}) async =>
                const Success(DisappearingUpdate(DisappearingSettings(), null)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('24 hours'), findsNothing);
      await tester.tap(find.text('Retry timer options'));
      await tester.pumpAndSettle();
      expect(find.text('24 hours'), findsOneWidget);
    },
  );

  testWidgets(
    'quick reply sends only the selected text and preserves an existing draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = TextEditingController(text: 'Unsent draft');
      String? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => ChatEmojiSheet.show(
                  ctx,
                  controller: controller,
                  onQuickReply: (text) => sent = text,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick replies'));
      await tester.pumpAndSettle();
      expect(sent, isNull);
      await tester.tap(find.text('Thank you 🙏'));
      await tester.pumpAndSettle();
      expect(sent, 'Thank you 🙏');
      expect(controller.text, 'Unsent draft');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  for (final own in [true, false]) {
    testWidgets(
      'reply card has readable sender ${own ? 'You' : 'Priya'} on a light surface',
      (tester) async {
        final scheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple)
            .copyWith(
              primary: Colors.deepPurple,
              primaryContainer: Colors.deepPurple,
              surface: Colors.white,
            );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: scheme),
            home: Scaffold(
              body: MessageQuote(
                reply: MessageReply(
                  id: 10,
                  body: 'Reply to this message',
                  senderId: own ? 1 : 9,
                  senderName: own ? 'QA' : 'Priya',
                ),
                meId: 1,
                onCancel: () {},
              ),
            ),
          ),
        );
        expect(find.text(own ? 'You' : 'Priya'), findsOneWidget);
        final card = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MessageQuote),
                matching: find.byType(Container),
              )
              .first,
        );
        expect((card.decoration as BoxDecoration).color, Colors.white);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact reaction badge retains total and opens details for many reaction groups',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MessageReactionBadge(
                    reactions: const [
                      MessageReaction(emoji: '👍', count: 3),
                      MessageReaction(emoji: '❤️', count: 2),
                      MessageReaction(emoji: '😂', count: 1),
                      MessageReaction(emoji: '🙏', count: 1),
                    ],
                    onTap: () => opened = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(
        tester.getSize(find.byType(MessageReactionBadge)).height,
        lessThan(30),
      );
      await tester.tap(find.byType(MessageReactionBadge));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only a completed horizontal swipe chooses a reply', (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 80,
              child: SwipeToReply(
                onReply: () => replies++,
                child: const ColoredBox(color: Colors.purple),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(SwipeToReply), const Offset(20, 0));
    await tester.pumpAndSettle();
    expect(replies, 0);
    await tester.drag(find.byType(SwipeToReply), const Offset(140, 0));
    await tester.pumpAndSettle();
    expect(replies, 1);
    await tester.drag(find.byType(SwipeToReply), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(replies, 1);
  });
}
