import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/models/author.dart';
import 'package:charmi_insta_freelancing/core/models/load.dart';
import 'package:charmi_insta_freelancing/core/models/post_type.dart';
import 'package:charmi_insta_freelancing/core/theme/app_theme.dart';
import 'package:charmi_insta_freelancing/features/feed/presentation/widgets/post_card.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

Load _load({bool own = false, bool requested = false, bool canMessage = true}) => Load(
      id: 1,
      title: 'Golden hour over the Alfama rooftops',
      body: 'Full set from this trip',
      isOwn: own,
      canMessage: canMessage,
      canReport: !own,
      canDelete: own,
      viewerHasRequested: requested,
      postType: const PostType(id: 2, slug: 'sell', name: 'Sell'),
      author: const Author(id: 2, name: 'Aria Lang'),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

void main() {
  testWidgets('renders author, caption and Request CTA for others', (tester) async {
    var requested = 0;
    await tester.pumpWidget(_host(PostCard(
      load: _load(),
      onRequest: () => requested++,
      onReport: () {},
      onDelete: () {},
    )));
    expect(find.text('Aria Lang'), findsOneWidget);
    expect(find.text('Golden hour over the Alfama rooftops'), findsOneWidget);
    expect(find.text('Request this post'), findsOneWidget);
    await tester.tap(find.text('Request this post'));
    expect(requested, 1);
  });

  testWidgets('already-requested shows disabled Requested state', (tester) async {
    await tester.pumpWidget(_host(PostCard(
      load: _load(requested: true),
      onRequest: () {},
      onReport: () {},
      onDelete: () {},
    )));
    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Request this post'), findsNothing);
  });

  testWidgets('owner sees status pill, not a request button', (tester) async {
    await tester.pumpWidget(_host(PostCard(
      load: _load(own: true),
      onRequest: () {},
      onReport: () {},
      onDelete: () {},
    )));
    expect(find.text('Request this post'), findsNothing);
    expect(find.textContaining('Your post'), findsOneWidget);
  });
}
