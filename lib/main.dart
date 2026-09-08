import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/di/injection.dart';
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

  // Initialize Google Mobile Ads (non-blocking) + session resolution.
  unawaited(AdService.initialize());
  unawaited(sl<AuthCubit>().bootstrap());

  runApp(const NexveeroApp());
}
