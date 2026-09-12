/// Named route paths. Centralized so navigation never uses raw strings.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String otp = '/otp';
  static const String pendingApproval = '/pending-approval';
  static const String changePassword = '/change-password';
  static const String feed = '/feed';
  static const String search = '/search';
  static const String createPost = '/create-post';
  static const String postDetail = '/post';
  static const String editProfile = '/edit-profile';
  static const String businessDetails = '/business-details';
  static const String businessProfile = '/business-profile';
  static const String chatThread = '/chat';
  static const String contactInfo = '/contact-info';
  static const String enterPin = '/enter-pin';
  static const String deleteAccount = '/delete-account';
  static const String manageLabels = '/chat-labels';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String offers = '/offers';
  static const String subscription = '/subscription';
  static const String wallet = '/wallet';
  static const String transactions = '/transactions';
  static const String paymentDetail = '/payment-detail';
  static const String businessDirectory = '/businesses';
  static const String adminBroadcastLimits = '/admin/broadcast-limits';
  static const String adminBroadcastGroups = '/admin/broadcast-groups';
  static const String createBroadcastGroup = '/admin/broadcast-groups/new';
  static const String adminUsers = '/admin/users';
  static const String adminSubscriptions = '/admin/subscriptions';
  static const String adminTags = '/admin/tags';
  static const String adminReports = '/admin/reports';
  static const String adminPackages = '/admin/packages';
  static const String adminPricing = '/admin/pricing';
  static const String groups = '/groups';
  static const String groupDetail = '/group';
  static const String security = '/security';
  static const String contactSync = '/find-friends';
  static const String userProfile = '/user';
  static const String createBroadcast = '/broadcast/new';
  static const String broadcastDetail = '/broadcast';
  static const String orders = '/orders';
  static const String createOrder = '/orders/new';
  static const String orderDetail = '/order';
  static const String paymentMethod = '/payment';
  // Additional routes are added as feature modules land.
}
