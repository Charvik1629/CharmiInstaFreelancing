import '../../../../core/models/user.dart';

import 'package:flutter/material.dart';

class AppTourStep {
  const AppTourStep({
    required this.target,
    required this.tab,
    required this.title,
    required this.description,
  });
  final GlobalKey target;
  final int tab;
  final String title;
  final String description;
}

/// Modal coach mark: highlights the real button without performing its action.
class AppTourOverlay extends StatelessWidget {
  const AppTourOverlay({
    super.key,
    required this.target,
    required this.title,
    required this.description,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });
  final Rect? target;
  final String title, description;
  final int index, total;
  final VoidCallback onNext, onBack, onSkip;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final top = target?.center.dy ?? constraints.maxHeight;
        final cardAtTop = top > constraints.maxHeight / 2;
        return Stack(
          children: [
            Positioned.fill(
              child: AbsorbPointer(
                child: CustomPaint(painter: _SpotlightPainter(target)),
              ),
            ),
            // Block taps through the spotlight; navigation is deliberate via Next.
            const Positioned.fill(
              child: ModalBarrier(
                dismissible: false,
                color: Colors.transparent,
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: cardAtTop ? MediaQuery.paddingOf(context).top + 24 : null,
              bottom: cardAtTop
                  ? null
                  : MediaQuery.paddingOf(context).bottom + 24,
              child: Semantics(
                liveRegion: true,
                child: Card(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.65,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'App tour · ${index + 1} of $total',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton(
                                onPressed: onSkip,
                                child: const Text('Skip tour'),
                              ),
                              if (index > 0)
                                TextButton(
                                  onPressed: onBack,
                                  child: const Text('Back'),
                                ),
                              FilledButton(
                                onPressed: onNext,
                                child: Text(
                                  index == total - 1 ? 'Get started' : 'Next',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.target);
  final Rect? target;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (target != null) {
      path.addRRect(
        RRect.fromRectAndRadius(target!.inflate(7), const Radius.circular(18)),
      );
    }
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
    if (target != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!.inflate(7), const Radius.circular(18)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}

List<AppTourStep> buildAppTourSteps(
  User user, {
  required List<GlobalKey> navigationKeys,
  required GlobalKey createKey,
}) {
  return [
    AppTourStep(
      target: navigationKeys[1],
      tab: 1,
      title: 'Discover posts',
      description: 'Tap Home to explore posts, products and business updates. Search the feed to find what you need.',
    ),
    AppTourStep(
      target: navigationKeys[3],
      tab: 3,
      title: 'Find people',
      description: user.isPending
          ? 'Search for people by name or phone number. Messaging becomes available after approval.'
          : 'Search by name or phone number, view a business profile and start a conversation.',
    ),
    AppTourStep(
      target: navigationKeys[2],
      tab: 2,
      title: 'Explore businesses',
      description: 'Tap Business to explore business posts and discover products and services.',
    ),
    if (user.canChat)
      AppTourStep(
        target: navigationKeys[0],
        tab: 0,
        title: 'Your conversations',
        description: 'Tap Chats for messages, questions and offers. Use + to find friends. You (Notes) is your private self-chat.',
      ),
    if (user.canPost)
      AppTourStep(
        target: createKey,
        tab: 1,
        title: 'Create a post',
        description: 'Tap this button to add photos, a description, tags and a location, then publish your post.',
      ),
    AppTourStep(
      target: navigationKeys[4],
      tab: 4,
      title: 'Your business profile',
      description: user.isPending
          ? 'Manage your business details here. While approval is pending you can browse, but creating posts, Ask, Offer and chat stay locked.'
          : 'Edit your profile and business details and manage your account here.',
    ),
  ];
}
