import 'package:flutter/widgets.dart';

import '../di/injection.dart';
import 'socket_service.dart';

/// Emits `presence:resume` / `presence:away` as the app moves between the
/// foreground and background, so peers see an accurate Online / last-seen state.
class PresenceObserver with WidgetsBindingObserver {
  SocketService? get _socket =>
      sl.isRegistered<SocketService>() ? sl<SocketService>() : null;

  void attach() => WidgetsBinding.instance.addObserver(this);
  void detach() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _socket?.presenceResume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _socket?.presenceAway();
    }
  }
}
