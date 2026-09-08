import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/theme/app_theme.dart';
import 'package:charmi_insta_freelancing/core/widgets/widgets.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  group('AppButton', () {
    testWidgets('primary invokes onPressed', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_host(
        AppButton(label: 'Go', onPressed: () => tapped++),
      ));
      await tester.tap(find.text('Go'));
      expect(tapped, 1);
    });

    testWidgets('disabled (null onPressed) is not tappable', (tester) async {
      await tester.pumpWidget(_host(const AppButton(label: 'Off', onPressed: null)));
      await tester.tap(find.text('Off'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading shows spinner and blocks taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_host(
        AppButton(label: 'X', isLoading: true, onPressed: () => tapped++),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Label hidden while loading.
      expect(find.text('X'), findsNothing);
      await tester.tap(find.byType(AppButton));
      expect(tapped, 0);
    });
  });

  group('AppAvatar', () {
    testWidgets('shows initials from name (max 2 letters)', (tester) async {
      await tester.pumpWidget(_host(const AppAvatar(name: 'Aria Lang Extra')));
      expect(find.text('AL'), findsOneWidget);
    });

    testWidgets('blank name falls back to ?', (tester) async {
      await tester.pumpWidget(_host(const AppAvatar(name: '   ')));
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('AppSegmented', () {
    testWidgets('tapping a segment reports its index', (tester) async {
      int? picked;
      await tester.pumpWidget(_host(
        AppSegmented(
          segments: const ['Feed', 'Chats', 'You'],
          selectedIndex: 0,
          onChanged: (i) => picked = i,
        ),
      ));
      await tester.tap(find.text('You'));
      expect(picked, 2);
    });
  });

  group('state views', () {
    testWidgets('ErrorView shows message and retry fires', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_host(
        ErrorView(message: 'Offline', onRetry: () => retried++),
      ));
      expect(find.text('Offline'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('ErrorView without onRetry hides the action', (tester) async {
      await tester.pumpWidget(_host(const ErrorView(message: 'Offline')));
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('EmptyView renders title and subtitle', (tester) async {
      await tester.pumpWidget(_host(
        const EmptyView(title: 'No posts', subtitle: 'Nothing here'),
      ));
      expect(find.text('No posts'), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
    });
  });

  group('ImagePlaceholder', () {
    testWidgets('renders the role icon; video shows a duration chip',
        (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 200,
        height: 150,
        child: ImagePlaceholder(
            role: PlaceholderRole.video, durationLabel: '0:12'),
      )));
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
    });

    testWidgets('avatar role renders a person icon', (tester) async {
      await tester.pumpWidget(_host(
        const SizedBox(width: 48, height: 48, child: ImagePlaceholder(role: PlaceholderRole.avatar)),
      ));
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });
  });

  group('AppBottomNav', () {
    testWidgets('reports tapped destination index', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(_host(
        AppBottomNav(
          currentIndex: 0,
          onTap: (i) => tappedIndex = i,
          items: const [
            AppNavItem(icon: Icons.home_outlined, label: 'Home'),
            AppNavItem(icon: Icons.person_outline, label: 'Profile'),
          ],
        ),
      ));
      // Icon-only nav (design): tap the second destination by its icon.
      await tester.tap(find.byIcon(Icons.person_outline));
      expect(tappedIndex, 1);
    });
  });
}
