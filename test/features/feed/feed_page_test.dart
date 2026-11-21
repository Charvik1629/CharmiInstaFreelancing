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
      author: const Author(id: 2, name: 'Aria Lang', businessName: 'Aria Industries'),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

void main() {
  testWidgets('shows company and four actions without request CTA', (tester) async {
    var asks = 0, offers = 0, shares = 0, reports = 0;
    await tester.pumpWidget(_host(PostCard(
      load: _load(),
      onRequest: () => fail('Removed request action must not run'),
      onAsk: () => asks++, onOffer: () => offers++, onShare: () => shares++,
      onReport: () => reports++, onDelete: () {},
    )));
    expect(find.text('Aria Industries'), findsOneWidget);
    expect(find.textContaining('Golden hour', findRichText: true), findsOneWidget);
    expect(find.text('Request this post'), findsNothing);
    await tester.tap(find.text('Share'));
    await tester.tap(find.text('Report'));
    expect(shares, 1);
    expect(reports, 1);
    // Capability flags remain authoritative for Ask and Offer.
    expect(asks, 0);
    expect(offers, 0);
  });

  testWidgets('previous request status does not restore removed CTA', (tester) async {
    await tester.pumpWidget(_host(PostCard(
      load: _load(requested: true), onRequest: () {}, onReport: () {}, onDelete: () {},
    )));
    expect(find.text('Requested'), findsNothing);
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
