import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/presentation/pages/business_feed_page.dart';
import '../../chat/domain/entities/unread_counts.dart';
import '../../chat/presentation/cubit/unread_cubit.dart';
import '../../chat/presentation/pages/chat_list_page.dart';
import '../../feed/presentation/pages/feed_page.dart';
import '../../profile/presentation/pages/profile_page.dart';
import '../../search/presentation/pages/search_page.dart';

/// The authenticated app shell: hosts the five bottom-nav destinations from the
/// design (Home · Search · Business · Chats · Profile — HTML line 4342). The
/// Chats tab shows a live unread badge from [UnreadCubit]. Uses an IndexedStack
/// so each tab keeps its state when switching.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final UnreadCubit _unread = sl<UnreadCubit>();

  // Chats now sits in slot 4 (Home · Search · Business · Chats · Profile).
  static const _chatIndex = 3;

  // Bumped when the user taps an already-active tab; the feed listens and
  // refreshes + scrolls to top (design: tapping Home/Business again reloads).
  final ValueNotifier<int> _homeReselect = ValueNotifier(0);
  final ValueNotifier<int> _businessReselect = ValueNotifier(0);

  StreamSubscription<NotificationEvent>? _notifSub;

  @override
  void initState() {
    super.initState();
    _unread.refresh();
    // Live toast for in-app notifications (e.g. someone asked a question).
    if (sl.isRegistered<SocketService>()) {
      _notifSub = sl<SocketService>().notifications.listen(_onNotification);
    }
  }

  void _onNotification(NotificationEvent e) {
    if (!mounted) return;
    final text = e.title ?? e.body ?? 'New notification';
    AppOverlays.snack(context, text);
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _homeReselect.dispose();
    _businessReselect.dispose();
    super.dispose();
  }

  late final _pages = [
    FeedPage(reselect: _homeReselect),
    const SearchPage(),
    BusinessFeedPage(reselect: _businessReselect),
    const ChatListPage(),
    const ProfilePage(),
  ];

  void _onTap(int i) {
    // Re-tapping the current tab reloads it instead of doing nothing.
    if (i == _index) {
      if (i == 0) _homeReselect.value++;
      if (i == 2) _businessReselect.value++;
      return;
    }
    setState(() => _index = i);
    // Opening the inbox clears its badge locally; the list shows per-row unread.
    if (i == _chatIndex) _unread.clearInbox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BlocBuilder<UnreadCubit, UnreadCounts>(
        bloc: _unread,
        builder: (context, counts) {
          final items = [
            const AppNavItem(icon: Icons.home_outlined, label: 'Home'),
            const AppNavItem(icon: Icons.search, label: 'Search'),
            const AppNavItem(
                icon: Icons.storefront_outlined, label: 'Business'),
            AppNavItem(
              icon: Icons.chat_bubble_outline,
              label: 'Chats',
              badge: counts.inbox > 0,
            ),
            const AppNavItem(icon: Icons.person_outline, label: 'Profile'),
          ];
          return AppBottomNav(
            items: items,
            currentIndex: _index,
            onTap: _onTap,
          );
        },
      ),
    );
  }
}
