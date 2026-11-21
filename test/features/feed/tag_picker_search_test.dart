import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:charmi_insta_freelancing/core/di/injection.dart';
import 'package:charmi_insta_freelancing/core/utils/result.dart';
import 'package:charmi_insta_freelancing/features/tags/domain/entities/tag.dart';
import 'package:charmi_insta_freelancing/features/tags/domain/repositories/tag_repository.dart';
import 'package:charmi_insta_freelancing/features/feed/presentation/widgets/tag_picker_sheet.dart';

class _Tags extends Mock implements TagRepository {}

void main() {
  tearDown(() => sl.reset());
  testWidgets('searching tags preserves a selected tag hidden by query', (
    tester,
  ) async {
    final repo = _Tags();
    const steel = Tag(id: 1, name: 'Steel');
    const transport = Tag(id: 2, name: 'Transport');
    when(() => repo.getTags())
        .thenAnswer((_) async => const Success([steel, transport]));
    sl.registerSingleton<TagRepository>(repo);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TagPickerSheet(initial: [steel])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'TRANSPORT');
    await tester.pump();
    expect(find.text('Steel'), findsNothing);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('Done (1)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Steel'))
          .selected,
      isTrue,
    );
  });
}
