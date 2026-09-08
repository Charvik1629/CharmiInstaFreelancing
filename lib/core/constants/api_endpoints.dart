/// Centralized relative endpoint paths (appended to [AppConfig.apiBaseUrl]).
///
/// Source of truth: the uploaded Post API documentation. Paths are relative and
/// never include the base URL. Grouped by API section.
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  // Pending backend (see MISSING_APIS.md) — wired so buttons work once added.
  static const String otpSend = '/auth/otp/send';
  static const String otpVerify = '/auth/otp/verify';
  static const String passwordForgot = '/auth/password/forgot';
  static const String passwordReset = '/auth/password/reset';
  static const String passwordChange = '/auth/password/change';

  // Profile / users
  static const String profile = '/profile';
  static const String users = '/users';
  static String user(Object id) => '/users/$id';

  // Post types
  static const String postTypes = '/post-types';

  // Loads (home feed == app "posts")
  static const String loads = '/loads';
  static String load(Object id) => '/loads/$id';
  static String loadRequest(Object id) => '/loads/$id/request';
  static String loadQuestions(Object id) => '/loads/$id/questions';
  static String loadOffers(Object id) => '/loads/$id/offers';
  static String loadReports(Object id) => '/loads/$id/reports';
  static String loadBoost(Object id) => '/loads/$id/boost';

  // Business feed (business posts + interspersed Google ads). Backend pending
  // (see BACKEND_REQUIREMENTS) — the cubit gates gracefully on 404.
  static const String businessPosts = '/business-posts';
  static String businessPostReport(Object id) => '/business-posts/$id/reports';

  // Offers
  static const String offers = '/offers';
  static const String offersUnreadCount = '/offers/unread-count';
  static String offer(Object id) => '/offers/$id';
  static String offerChat(Object id) => '/offers/$id/chat';

  // Chats & messages
  static const String chats = '/chats';
  static const String chatsUnreadCount = '/chats/unread-count';
  static const String chatsPinRequirement = '/chats/pin-requirement';
  static const String questions = '/questions';
  static const String chatLabels = '/chat-labels';
  static String chatLabel(Object id) => '/chat-labels/$id';
  static String conversationLabel(Object conversationId, Object labelId) =>
      '/conversations/$conversationId/labels/$labelId';
  static String conversation(Object id) => '/conversations/$id';
  static String conversationMessages(Object id) => '/conversations/$id/messages';
  static String conversationRead(Object id) => '/conversations/$id/read';

  // Groups
  static const String groupsRecommended = '/groups/recommended';
  static const String groups = '/groups';
  static String group(Object id) => '/groups/$id';
  static String groupMembers(Object id) => '/groups/$id/members';
  static String groupLeave(Object id) => '/groups/$id/leave';
  static String groupMember(Object id, Object userId) =>
      '/groups/$id/members/$userId';
  static String groupJoinRequests(Object id) => '/groups/$id/join-requests';
  static String groupJoinRequestMe(Object id) => '/groups/$id/join-requests/me';
  static String groupJoinRequestApprove(Object id, Object reqId) =>
      '/groups/$id/join-requests/$reqId/approve';
  static String groupJoinRequestDecline(Object id, Object reqId) =>
      '/groups/$id/join-requests/$reqId/decline';
  static const String adminGroupsJoinRequestSummary =
      '/admin/groups/join-request-summary';

  // Wallet & credits
  static const String wallet = '/wallet';
  static const String walletPackages = '/wallet/packages';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletCheckout = '/wallet/checkout';
  static const String walletVerify = '/wallet/verify';
  static const String walletDemoTopup = '/wallet/demo-topup';

  // Admin — wallet (packages, settings, manual adjust)
  static const String adminWalletPackages = '/admin/wallet/packages';
  static String adminWalletPackage(Object id) => '/admin/wallet/packages/$id';
  static const String adminWalletSettings = '/admin/wallet/settings';
  static String adminWalletAdjust(Object userId) =>
      '/admin/wallet/users/$userId/adjust';

  // Broadcasts
  static const String broadcasts = '/broadcasts';
  static String broadcast(Object id) => '/broadcasts/$id';
  static String broadcastMessages(Object id) => '/broadcasts/$id/messages';

  // Admin
  static const String adminReports = '/admin/reports';
  static const String adminReportsPendingCount = '/admin/reports/pending-count';
  static String adminReport(Object id) => '/admin/reports/$id';

  // Tags
  static const String tags = '/tags';
  static const String adminTags = '/admin/tags';
  static String adminTag(Object id) => '/admin/tags/$id';

  // Notifications (BACKEND_REQUIREMENTS G1 — not live yet; gated in the app)
  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static String notificationRead(Object id) => '/notifications/$id/read';

  // Subscription (user)
  static const String subscription = '/subscription';
  static const String subscriptionPlans = '/subscription/plans';
  static const String subscriptionRequests = '/subscription/requests';

  // Admin — subscriptions
  static const String adminSubPlans = '/admin/subscriptions/plans';
  static String adminSubPlan(Object id) => '/admin/subscriptions/plans/$id';
  static const String adminSubRequests = '/admin/subscriptions/requests';
  static String adminSubRequestApprove(Object id) =>
      '/admin/subscriptions/requests/$id/approve';
  static String adminSubRequestReject(Object id) =>
      '/admin/subscriptions/requests/$id/reject';
  static const String adminSubSettings = '/admin/subscriptions/settings';
  static String adminSubUserAssign(Object userId) =>
      '/admin/subscriptions/users/$userId/assign';
  static String adminSubUserRemove(Object userId) =>
      '/admin/subscriptions/users/$userId';

  // Admin — user approval (super-admin gate)
  static const String adminUsers = '/admin/users';
  static const String adminUsersPendingCount = '/admin/users/pending-count';
  static String adminUserApprove(Object id) => '/admin/users/$id/approve';
  static String adminUserReject(Object id) => '/admin/users/$id/reject';

  // Security / chat PIN
  static const String securityPin = '/security/pin';

  // Devices, realtime & push
  static const String devices = '/devices';
  static const String realtimeConfig = '/realtime/config';
  static const String socketAuth = '/socket/auth';

  // Contact sync — endpoint not documented yet. Constant is ready so the upload
  // is a one-line wire-up once the backend ships it (payload is already built).
  static const String contactSync = '/contacts/sync';
}
