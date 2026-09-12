import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/di/injection.dart';
import 'core/push/push_service.dart';
import 'core/realtime/socket_service.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A 401 from any request clears the session; reflect that in the AuthCubit so
  // the router redirects back to login.
  await configureDependencies(
    onUnauthorized: () {
      if (sl.isRegistered<AuthCubit>()) sl<AuthCubit>().logout();
    },
  );

  // Firebase (push). Non-fatal if it can't init (e.g. missing native config).
  try {
    await PushService.initFirebase();
  } catch (_) {}

  // Initialize Google Mobile Ads (non-blocking) + session resolution. Register
  // the push token once the session resolves and the user is authenticated.
  unawaited(AdService.initialize());
  unawaited(sl<AuthCubit>().bootstrap().then((_) {
    if (sl<AuthCubit>().state.isAuthenticated) {
      unawaited(sl<PushService>().start());
      unawaited(sl<SocketService>().connect());
    }
  }));

  runApp(const NexveeroApp());
}
