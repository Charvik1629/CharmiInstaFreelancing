import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/push/push_service.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/storage/storage_manager.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import 'widgets/app_tour_overlay.dart';
import 'app_tour_progress.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  // Nav order: Chats · Home · Business · Search · Profile. App opens on Home.
  int _index = 1;
  final _navKeys = List.generate(5, (_) => GlobalKey());
  final _createKey = GlobalKey();
  final _tourCanvasKey = GlobalKey();
  List<AppTourStep> _tourSteps = [];
  int? _tourStep;
  Rect? _tourTarget;
  int? _activeTourUserId;
  late final _tourProgress = AppTourProgress(sl<StorageManager>());
  int _tourGeneration = 0;
  final UnreadCubit _unread = sl<UnreadCubit>();

  static const _chatIndex = 0;
  static const _homeIndex = 1;
  static const _businessIndex = 2;

  // Bumped when the user taps an already-active tab; the feed listens and
  // refreshes + scrolls to top (design: tapping Home/Business again reloads).
  final ValueNotifier<int> _profileRefresh = ValueNotifier(0);
  final ValueNotifier<int> _homeReselect = ValueNotifier(0);
  final ValueNotifier<int> _businessReselect = ValueNotifier(0);

  StreamSubscription<NotificationEvent>? _notifSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (context.read<AuthCubit>().state.user?.canChat == true) {
      _unread.refresh();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());
    // Live toast for in-app notifications (e.g. someone asked a question).
    if (sl.isRegistered<SocketService>()) {
      _notifSub = sl<SocketService>().notifications.listen(_onNotification);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On returning to the foreground, reconnect/poke the socket so lists and
    // open threads refetch and catch up anything missed while backgrounded
    // (new chats, messages, posts) — no manual pull-to-refresh needed. Also
    // refresh the unread badge.
    if (state == AppLifecycleState.resumed) {
      if (sl.isRegistered<SocketService>()) sl<SocketService>().onAppResumed();
      if (context.read<AuthCubit>().state.user?.canChat == true) {
        _unread.refresh();
      }
      if (sl.isRegistered<PushService>()) unawaited(sl<PushService>().start());
    }
  }

  void _onNotification(NotificationEvent e) {
    if (!mounted) return;
    final text = e.title ?? e.body ?? 'New notification';
    AppOverlays.snack(context, text);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notifSub?.cancel();
    _profileRefresh.dispose();
    _homeReselect.dispose();
    _businessReselect.dispose();
    super.dispose();
  }

  late final _pages = [
    const ChatListPage(),
    FeedPage(reselect: _homeReselect, createButtonKey: _createKey),
    BusinessFeedPage(reselect: _businessReselect),
    const SearchPage(),
    ProfilePage(refresh: _profileRefresh),
  ];

  void _onTap(int i) {
    if (i == 4) _profileRefresh.value++;
    // Re-tapping the current tab reloads it instead of doing nothing.
    if (i == _index) {
      if (i == _homeIndex) _homeReselect.value++;
      if (i == _businessIndex) _businessReselect.value++;
      return;
    }
    setState(() => _index = i);
    // Opening the inbox clears its badge locally; the list shows per-row unread.
    if (i == _chatIndex &&
        context.read<AuthCubit>().state.user?.canChat == true) {
      _unread.clearInbox();
    }
    // The Business feed must fetch fresh data every time it's opened (not only
    // when re-tapped), so a post created elsewhere shows up without an app
    // restart. The feed listens to this notifier and refreshes.
    if (i == _businessIndex) _businessReselect.value++;
  }

  void _maybeStartTour() {
    if (!mounted) return;
    final user = context.read<AuthCubit>().state.user;
    if (user == null || user.needsBusinessDetails) return;
    if (!_tourProgress.hasSeen(user.id)) _startTour();
  }

  void _startTour() {
    final user = context.read<AuthCubit>().state.user;
    if (user == null) return;
    _activeTourUserId = user.id;
    _tourSteps = buildAppTourSteps(
      user,
      navigationKeys: _navKeys,
      createKey: _createKey,
    );
    _showTourStep(0);
  }

  void _showTourStep(int step) {
    final generation = ++_tourGeneration;
    setState(() {
      _tourStep = step;
      _index = _tourSteps[step].tab;
      _tourTarget = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _tourGeneration || _tourStep == null) {
        return;
      }
      final target = _tourSteps[step].target.currentContext?.findRenderObject();
      final canvas = _tourCanvasKey.currentContext?.findRenderObject();
      if (target is RenderBox && target.hasSize && canvas is RenderBox) {
        final origin = canvas.globalToLocal(target.localToGlobal(Offset.zero));
        setState(() => _tourTarget = origin & target.size);
      }
    });
  }

  Future<void> _finishTour() async {
    final userId = _activeTourUserId;
    ++_tourGeneration;
    setState(() {
      _tourStep = null;
      _tourTarget = null;
      _index = 1;
    });
    if (userId != null) await _tourProgress.markDone(userId);
  }

  @override
  void didChangeMetrics() {
    if (_tourStep != null && mounted) _showTourStep(_tourStep!);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tourStep == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tourStep != null) _finishTour();
      },
      child: Stack(
        key: _tourCanvasKey,
        children: [
          Scaffold(
            body: IndexedStack(index: _index, children: _pages),
            bottomNavigationBar: BlocBuilder<UnreadCubit, UnreadCounts>(
              bloc: _unread,
              builder: (context, counts) {
                final items = [
                  AppNavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chats',
                    badge: counts.inbox > 0 && context.watch<AuthCubit>().state.user?.canChat == true,
                  ),
                  const AppNavItem(icon: Icons.home_outlined, label: 'Home'),
                  const AppNavItem(
                    icon: Icons.storefront_outlined,
                    label: 'Business',
                  ),
                  const AppNavItem(icon: Icons.search, label: 'Search'),
                  const AppNavItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                  ),
                ];
                return AppBottomNav(
                  items: items,
                  itemKeys: _navKeys,
                  currentIndex: _index,
                  onTap: _onTap,
                );
              },
            ),
          ),
          if (_tourStep != null)
            Positioned.fill(
              child: AppTourOverlay(
                target: _tourTarget,
                title: _tourSteps[_tourStep!].title,
                description: _tourSteps[_tourStep!].description,
                index: _tourStep!,
                total: _tourSteps.length,
                onSkip: _finishTour,
                onBack: () { final step = _tourStep; if (step != null && step > 0) _showTourStep(step - 1); },
                onNext: () {
                  final step = _tourStep;
                  if (step == null) return;
                  if (step == _tourSteps.length - 1) {
                    _finishTour();
                  } else {
                    _showTourStep(step + 1);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
