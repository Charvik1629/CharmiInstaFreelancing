import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charmi_insta_freelancing/core/di/injection.dart';
import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/admin/domain/repositories/admin_repository.dart';
import 'package:charmi_insta_freelancing/features/profile/presentation/widgets/user_approvals_tile.dart';

class _Repo extends Mock implements AdminRepository {}

void main() {
  late _Repo repo;
  setUp(() {
    repo = _Repo();
    sl.registerSingleton<AdminRepository>(repo);
  });
  tearDown(() => sl.reset());

  testWidgets('shows pending count and refreshes down to zero', (tester) async {
    var count = 12;
    when(() => repo.pendingUsersCount()).thenAnswer((_) async => Success(count));
    final refresh = ValueNotifier(0);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: UserApprovalsTile(refresh: refresh),
    )));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    count = 0;
    refresh.value++;
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('12'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    refresh.dispose();
  });

  testWidgets('API failure does not invent a zero count', (tester) async {
    when(() => repo.pendingUsersCount())
        .thenAnswer((_) async => const Err(NetworkFailure()));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: UserApprovalsTile(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('User approvals'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
