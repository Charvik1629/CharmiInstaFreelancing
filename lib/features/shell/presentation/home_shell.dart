import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
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

  @override
  void initState() {
    super.initState();
    _unread.refresh();
  }

  static const _pages = [
    FeedPage(),
    SearchPage(),
    BusinessFeedPage(),
    ChatListPage(),
    ProfilePage(),
  ];

  void _onTap(int i) {
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
