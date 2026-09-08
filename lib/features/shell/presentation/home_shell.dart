import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/presentation/pages/view_business_page.dart';
import '../../chat/domain/entities/unread_counts.dart';
import '../../chat/presentation/cubit/unread_cubit.dart';
import '../../chat/presentation/pages/chat_list_page.dart';
import '../../feed/presentation/pages/feed_page.dart';
import '../../profile/presentation/pages/profile_page.dart';
import '../../status/presentation/pages/status_page.dart';

/// The authenticated app shell: hosts the five bottom-nav destinations from the
/// updated design (Feed · Chat · View Business · Status · Profile). The Chat tab
/// shows a live unread badge from [UnreadCubit]. Uses an IndexedStack so each
/// tab keeps its state when switching.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final UnreadCubit _unread = sl<UnreadCubit>();

  static const _chatIndex = 1;

  @override
  void initState() {
    super.initState();
    _unread.refresh();
  }

  static const _pages = [
    FeedPage(),
    ChatListPage(),
    ViewBusinessPage(),
    StatusPage(),
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
            const AppNavItem(icon: Icons.home_outlined, label: 'Feed'),
            AppNavItem(
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              badge: counts.inbox > 0,
            ),
            const AppNavItem(
                icon: Icons.storefront_outlined, label: 'View Business'),
            const AppNavItem(
                icon: Icons.motion_photos_on_outlined, label: 'Status'),
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
