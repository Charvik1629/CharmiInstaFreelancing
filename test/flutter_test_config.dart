import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Global test setup. Disables google_fonts runtime HTTP fetching so tests run
/// offline and deterministically (falls back to the default font silently).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
