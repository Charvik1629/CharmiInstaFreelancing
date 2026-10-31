import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

/// Helper to start a 1:1 chat with a user, checking if chat PIN is required first.
Future<void> startChatWithPinCheck(
  BuildContext context, {
  required int userId,
  required String name,
  String? avatarUrl,
  Future<void> Function(Conversation conversation)? onSuccess,
}) async {
  final repo = sl<ChatRepository>();
  final pinReq = await AppLoader.run(repo.chatPinRequired(userId));
  if (!context.mounted) return;

  String? pin;
  if (pinReq.valueOrNull == true) {
    pin = await context.push<String>(
      AppRoutes.enterPin,
      extra: {'name': name, 'avatar': avatarUrl},
    );
    if (pin == null) return; // cancelled
  }

  final result = await AppLoader.run(repo.startChat(userId, pin: pin));
  if (!context.mounted) return;
  switch (result) {
    case Success(value: final conversation):
      if (onSuccess != null) {
        await onSuccess(conversation);
      } else {
        context.push(AppRoutes.chatThread, extra: conversation);
      }
    case Err(failure: final f):
      AppOverlays.snack(context, f.message);
  }
}
