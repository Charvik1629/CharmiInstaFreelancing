import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';
import 'package:charmi_insta_freelancing/features/shell/presentation/widgets/app_tour_overlay.dart';

void main() {
  test('pending tour omits chat/post steps even if backend grants them', () {
    final keys = List.generate(5, (_) => GlobalKey());
    final create = GlobalKey();
    final user = User.fromJson({
      'id': 1,
      'name': 'Pending',
      'approval_status': 'pending',
      'capabilities': {
        'can_chat': true,
        'can_offer': true,
        'can_ask': true,
        'can_create_post': true,
      },
    });
    final steps = buildAppTourSteps(
      user,
      navigationKeys: keys,
      createKey: create,
    );
    expect(steps.map((s) => s.tab), [1, 3, 2, 4]);
    expect(
      steps.any((s) => s.target == create || s.target == keys[0]),
      isFalse,
    );
    expect(
      user.canPost || user.canOffer || user.canChat || user.canAsk,
      isFalse,
    );
  });
  test('approved tour includes actual create button and chat targets', () {
    final keys = List.generate(5, (_) => GlobalKey());
    final create = GlobalKey();
    final steps = buildAppTourSteps(
      const User(
        id: 1,
        name: 'Approved',
        capabilities: {'can_create_post': true, 'can_chat': true},
      ),
      navigationKeys: keys,
      createKey: create,
    );
    expect(steps.any((s) => s.target == create && s.tab == 1), isTrue);
    expect(steps.any((s) => s.target == keys[0]), isTrue);
  });
  testWidgets('coach mark handles Next/Skip and blocks target actions', (
    tester,
  ) async {
    var actions = 0, next = 0, skip = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 20,
                top: 500,
                width: 80,
                height: 40,
                child: TextButton(
                  onPressed: () => actions++,
                  child: const Text('Target'),
                ),
              ),
              Positioned.fill(
                child: AppTourOverlay(
                  target: const Rect.fromLTWH(20, 500, 80, 40),
                  title: 'Discover posts',
                  description: 'Tap here to discover posts.',
                  index: 0,
                  total: 4,
                  onNext: () => next++,
                  onBack: () {},
                  onSkip: () => skip++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(40, 520));
    expect(actions, 0);
    await tester.tap(find.text('Next'));
    expect(next, 1);
    await tester.tap(find.text('Skip tour'));
    expect(skip, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('last step exposes Back and Get started', (tester) async {
    var back = 0, finish = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AppTourOverlay(
          target: const Rect.fromLTWH(0, 500, 60, 40),
          title: 'Your profile',
          description: 'Manage business details here.',
          index: 3,
          total: 4,
          onBack: () => back++,
          onNext: () => finish++,
          onSkip: () {},
        ),
      ),
    );
    await tester.tap(find.text('Back'));
    await tester.tap(find.text('Get started'));
    expect(back, 1);
    expect(finish, 1);
    expect(tester.takeException(), isNull);
  });
}
