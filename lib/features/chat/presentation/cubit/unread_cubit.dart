import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/unread_counts.dart';
import '../../domain/repositories/chat_repository.dart';

/// Holds the app-wide unread badge totals. Registered as a singleton so the app
/// shell (nav badge) and any screen can read/refresh the same counts. Failures
/// are swallowed — a badge is non-critical, so it just keeps the last value.
class UnreadCubit extends Cubit<UnreadCounts> {
  UnreadCubit(this._repository) : super(const UnreadCounts());

  final ChatRepository _repository;

  Future<void> refresh() async {
    final result = await _repository.getUnreadCounts();
    if (result case Success(value: final counts)) emit(counts);
  }

  /// Clears the badge locally (e.g. after opening the inbox) until the next
  /// server refresh.
  void clearInbox() => emit(UnreadCounts(offers: state.offers));

  /// Applies counts pushed live over the socket (`unread:update`).
  void setCounts(UnreadCounts counts) => emit(counts);
}
