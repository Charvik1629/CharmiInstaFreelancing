import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/shell/presentation/home_shell.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/otp_verification_page.dart';
import '../../features/auth/presentation/pages/pending_approval_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../core/models/user.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/chat/domain/entities/conversation.dart';
import '../../features/chat/presentation/pages/chat_thread_page.dart';
import '../../features/chat/presentation/pages/manage_labels_page.dart';
import '../../features/feed/presentation/pages/create_post_page.dart';
import '../../features/feed/presentation/pages/post_detail_page.dart';
import '../../core/models/load.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/offers/presentation/pages/offers_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/business_details_page.dart';
import '../../features/profile/presentation/pages/business_profile_page.dart';
import '../../features/wallet/presentation/pages/transactions_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import '../../features/subscription/presentation/pages/subscription_page.dart';
import '../../features/subscription/presentation/pages/admin_subscriptions_page.dart';
import '../../features/tags/presentation/pages/admin_tags_page.dart';
import '../../features/admin/presentation/pages/admin_reports_page.dart';
import '../../features/admin/presentation/pages/admin_users_page.dart';
import '../../features/admin/presentation/pages/admin_packages_page.dart';
import '../../features/admin/presentation/pages/admin_pricing_page.dart';
import '../../features/groups/domain/entities/group.dart';
import '../../features/groups/presentation/pages/groups_list_page.dart';
import '../../features/groups/presentation/pages/group_detail_page.dart';
import '../../features/security/presentation/pages/security_page.dart';
import '../../features/contacts/presentation/pages/contact_sync_page.dart';
import '../../features/profile/presentation/pages/user_profile_page.dart';
import '../../features/broadcasts/presentation/pages/create_broadcast_page.dart';
import '../../features/broadcasts/presentation/pages/broadcast_detail_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/orders/presentation/pages/create_order_page.dart';
import '../../features/orders/presentation/pages/order_detail_page.dart';
import '../../features/payment/presentation/pages/payment_method_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../di/injection.dart';
import '../storage/storage_keys.dart';
import '../storage/storage_manager.dart';
import 'app_routes.dart';
import 'go_router_refresh.dart';

/// App router with auth-aware redirects. The redirect runs on every auth-state
/// change (via [GoRouterRefreshStream]) and enforces:
///   unknown → stay on splash
///   onboarding not seen → onboarding
///   unauthenticated → login/register only
///   authenticated → feed (kept out of splash/auth screens)
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(sl<AuthCubit>().stream),
    redirect: _redirect,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.onboarding, builder: (_, _) => const OnboardingPage()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterPage()),
      GoRoute(path: AppRoutes.feed, builder: (_, _) => const HomeShell()),
      GoRoute(path: AppRoutes.search, builder: (_, _) => const SearchPage()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, state) => OtpVerificationPage(
          destination: state.uri.queryParameters['to'],
          channel: state.uri.queryParameters['channel'] == 'mobile'
              ? OtpChannel.mobile
              : OtpChannel.email,
        ),
      ),
      GoRoute(
        path: AppRoutes.pendingApproval,
        builder: (_, state) {
          final extra = state.extra;
          return PendingApprovalPage(
            user: extra is User ? extra : null,
            rejected: extra is bool ? extra : false,
          );
        },
      ),
      GoRoute(path: AppRoutes.changePassword, builder: (_, _) => const ChangePasswordPage()),
      GoRoute(path: AppRoutes.createPost, builder: (_, _) => const CreatePostPage()),
      GoRoute(
        path: AppRoutes.postDetail,
        builder: (_, state) => PostDetailPage(load: state.extra as Load),
      ),
      GoRoute(path: AppRoutes.editProfile, builder: (_, _) => const EditProfilePage()),
      GoRoute(path: AppRoutes.businessDetails, builder: (_, _) => const BusinessDetailsPage()),
      GoRoute(path: AppRoutes.businessProfile, builder: (_, _) => const BusinessProfilePage()),
      GoRoute(
        path: AppRoutes.chatThread,
        builder: (_, state) =>
            ChatThreadPage(conversation: state.extra as Conversation),
      ),
      GoRoute(
          path: AppRoutes.manageLabels,
          builder: (_, _) => const ManageLabelsPage()),
      GoRoute(path: AppRoutes.settings, builder: (_, _) => const SettingsPage()),
      GoRoute(path: AppRoutes.notifications, builder: (_, _) => const NotificationsPage()),
      GoRoute(path: AppRoutes.offers, builder: (_, _) => const OffersPage()),
      GoRoute(path: AppRoutes.subscription, builder: (_, _) => const SubscriptionPage()),
      GoRoute(path: AppRoutes.wallet, builder: (_, _) => const WalletPage()),
      GoRoute(path: AppRoutes.transactions, builder: (_, _) => const TransactionsPage()),
      GoRoute(path: AppRoutes.adminUsers, builder: (_, _) => const AdminUsersPage()),
      GoRoute(path: AppRoutes.adminSubscriptions, builder: (_, _) => const AdminSubscriptionsPage()),
      GoRoute(path: AppRoutes.adminTags, builder: (_, _) => const AdminTagsPage()),
      GoRoute(path: AppRoutes.adminReports, builder: (_, _) => const AdminReportsPage()),
      GoRoute(path: AppRoutes.adminPackages, builder: (_, _) => const AdminPackagesPage()),
      GoRoute(path: AppRoutes.adminPricing, builder: (_, _) => const AdminPricingPage()),
      GoRoute(path: AppRoutes.groups, builder: (_, _) => const GroupsListPage()),
      GoRoute(
        path: AppRoutes.groupDetail,
        builder: (_, state) => GroupDetailPage(group: state.extra as Group),
      ),
      GoRoute(path: AppRoutes.security, builder: (_, _) => const SecurityPage()),
      GoRoute(path: AppRoutes.contactSync, builder: (_, _) => const ContactSyncPage()),
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (_, state) => UserProfilePage(userId: state.extra as int),
      ),
      GoRoute(
        path: AppRoutes.createBroadcast,
        builder: (_, _) => const CreateBroadcastPage(),
      ),
      GoRoute(
        path: AppRoutes.broadcastDetail,
        builder: (_, state) => BroadcastDetailPage(broadcastId: state.extra as int),
      ),
      GoRoute(path: AppRoutes.orders, builder: (_, _) => const OrdersPage()),
      GoRoute(path: AppRoutes.createOrder, builder: (_, _) => const CreateOrderPage()),
      GoRoute(path: AppRoutes.orderDetail, builder: (_, _) => const OrderDetailPage()),
      GoRoute(path: AppRoutes.paymentMethod, builder: (_, _) => const PaymentMethodPage()),
    ],
  );

  static String? _redirect(BuildContext context, GoRouterState state) {
    final auth = sl<AuthCubit>().state;
    final location = state.matchedLocation;

    // Session not resolved yet → hold on splash.
    if (auth.status == AuthStatus.unknown) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final onboardingSeen =
        sl<StorageManager>().getBool(StorageKeys.onboardingSeen);
    const authScreens = {
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
      AppRoutes.otp,
      AppRoutes.pendingApproval,
    };
    final loggingIn = authScreens.contains(location);

    if (!auth.isAuthenticated) {
      if (!onboardingSeen && location != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }
      if (onboardingSeen && !loggingIn) return AppRoutes.login;
      return null;
    }

    // Authenticated: keep out of splash / onboarding / auth screens.
    if (location == AppRoutes.splash ||
        location == AppRoutes.onboarding ||
        loggingIn) {
      return AppRoutes.feed;
    }
    return null;
  }
}
