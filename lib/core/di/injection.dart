import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../push/push_service.dart';
import '../realtime/socket_service.dart';
import '../network/network_info.dart';
import '../permissions/permission_manager.dart';
import '../storage/storage_manager.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/auth/presentation/cubit/register_cubit.dart';
import '../../features/feed/data/datasources/feed_remote_data_source.dart';
import '../../features/feed/data/repositories/feed_repository_impl.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/feed/presentation/cubit/create_post_cubit.dart';
import '../../features/feed/presentation/cubit/feed_cubit.dart';
import '../../features/business/data/datasources/business_directory_data_source.dart';
import '../../features/business/data/repositories/business_directory_repository_impl.dart';
import '../../features/business/domain/repositories/business_directory_repository.dart';
import '../../features/orders/data/orders_remote_data_source.dart';
import '../../features/orders/data/orders_repository_impl.dart';
import '../../features/orders/domain/orders_repository.dart';
import '../../features/chat/data/datasources/chat_remote_data_source.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/presentation/cubit/chat_list_cubit.dart';
import '../../features/chat/presentation/cubit/chat_labels_cubit.dart';
import '../../features/chat/presentation/cubit/unread_cubit.dart';
import '../../features/search/data/datasources/search_remote_data_source.dart';
import '../../features/search/data/repositories/search_repository_impl.dart';
import '../../features/search/domain/repositories/search_repository.dart';
import '../../features/search/presentation/cubit/search_cubit.dart';
import '../../features/offers/data/datasources/offers_remote_data_source.dart';
import '../../features/offers/data/repositories/offers_repository_impl.dart';
import '../../features/offers/domain/repositories/offers_repository.dart';
import '../../features/offers/presentation/cubit/offers_list_cubit.dart';
import '../../features/wallet/data/datasources/wallet_remote_data_source.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/presentation/cubit/transactions_cubit.dart';
import '../../features/wallet/presentation/cubit/wallet_cubit.dart';
import '../../features/admin/data/datasources/admin_remote_data_source.dart';
import '../../features/admin/data/repositories/admin_repository_impl.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/admin/presentation/cubit/admin_reports_cubit.dart';
import '../../features/admin/presentation/cubit/admin_users_cubit.dart';
import '../../features/admin/data/datasources/admin_wallet_remote_data_source.dart';
import '../../features/admin/data/repositories/admin_wallet_repository_impl.dart';
import '../../features/admin/domain/repositories/admin_wallet_repository.dart';
import '../../features/admin/presentation/cubit/admin_packages_cubit.dart';
import '../../features/admin/presentation/cubit/admin_wallet_settings_cubit.dart';
import '../../features/subscription/data/datasources/subscription_remote_data_source.dart';
import '../../features/subscription/data/datasources/admin_subscription_remote_data_source.dart';
import '../../features/subscription/data/repositories/subscription_repository_impl.dart';
import '../../features/subscription/data/repositories/admin_subscription_repository_impl.dart';
import '../../features/subscription/domain/repositories/subscription_repository.dart';
import '../../features/subscription/domain/repositories/admin_subscription_repository.dart';
import '../../features/subscription/presentation/cubit/subscription_cubit.dart';
import '../../features/subscription/presentation/cubit/admin_sub_requests_cubit.dart';
import '../../features/subscription/presentation/cubit/admin_sub_plans_cubit.dart';
import '../../features/tags/data/datasources/tag_remote_data_source.dart';
import '../../features/tags/data/repositories/tag_repository_impl.dart';
import '../../features/tags/domain/repositories/tag_repository.dart';
import '../../features/tags/presentation/cubit/admin_tags_cubit.dart';
import '../../features/groups/data/datasources/groups_remote_data_source.dart';
import '../../features/groups/data/repositories/groups_repository_impl.dart';
import '../../features/groups/domain/repositories/groups_repository.dart';
import '../../features/groups/presentation/cubit/group_detail_cubit.dart';
import '../../features/groups/presentation/cubit/groups_list_cubit.dart';
import '../../features/security/data/security_remote_data_source.dart';
import '../../features/security/domain/security_repository.dart';
import '../../features/security/presentation/cubit/security_cubit.dart';
import '../../features/contacts/data/contacts_data_source.dart';
import '../../features/contacts/domain/contacts_repository.dart';
import '../../features/contacts/presentation/cubit/contact_sync_cubit.dart';
import '../../features/broadcasts/data/broadcasts_remote_data_source.dart';
import '../../features/broadcasts/domain/broadcasts_repository.dart';
import '../../features/broadcasts/presentation/cubit/create_broadcast_cubit.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/cubit/user_profile_cubit.dart';
import '../../features/profile/presentation/cubit/business_details_cubit.dart';
import '../../features/profile/presentation/cubit/business_profile_cubit.dart';
import '../../features/notifications/data/datasources/notifications_remote_data_source.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/post_types/data/datasources/post_type_remote_data_source.dart';
import '../../features/post_types/data/repositories/post_type_repository_impl.dart';
import '../../features/post_types/domain/repositories/post_type_repository.dart';

/// Global service locator. Feature modules register their own datasources /
/// repositories / cubits by extending [registerFeatureDependencies] as they are
/// built, keeping this file from becoming a dumping ground.
final GetIt sl = GetIt.instance;

/// Called once at startup before `runApp`. Registers core singletons that the
/// whole app depends on.
Future<void> configureDependencies({void Function()? onUnauthorized}) async {
  // Storage must be created async first.
  final storage = await StorageManager.create();
  sl.registerSingleton<StorageManager>(storage);

  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfo(Connectivity()),
  );

  // Reusable runtime-permission manager (contacts, camera, photos, …).
  sl.registerLazySingleton<PermissionManager>(() => const PermissionManager());

  sl.registerLazySingleton<ApiClient>(
    () => ApiClient.create(
      storage: sl<StorageManager>(),
      onUnauthorized: onUnauthorized,
    ),
  );

  // Feature registrations are added here as modules land.
  registerFeatureDependencies();
}

/// Extended by each feature module (auth, feed, …) as it is implemented.
void registerFeatureDependencies() {
  // Post types (shared: composer + feed filters).
  sl.registerLazySingleton<PostTypeRemoteDataSource>(
    () => PostTypeRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<PostTypeRepository>(
    () => PostTypeRepositoryImpl(sl<PostTypeRemoteDataSource>()),
  );

  // Auth.
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl<AuthRemoteDataSource>(), sl<StorageManager>()),
  );
  // Single app-wide session cubit (shared by the router guard and the UI).
  sl.registerSingleton<AuthCubit>(AuthCubit(sl<AuthRepository>()));
  sl.registerLazySingleton<PushService>(() => PushService(sl<ApiClient>()));
  sl.registerLazySingleton<SocketService>(
      () => SocketService(sl<ApiClient>(), sl<StorageManager>()));
  // Fresh form cubits per page mount.
  sl.registerFactory<LoginCubit>(() => LoginCubit(sl<AuthRepository>()));
  sl.registerFactory<RegisterCubit>(() => RegisterCubit(sl<AuthRepository>()));

  // Feed.
  sl.registerLazySingleton<FeedRemoteDataSource>(
    () => FeedRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<FeedRepository>(
    () => FeedRepositoryImpl(sl<FeedRemoteDataSource>()),
  );
  sl.registerFactory<FeedCubit>(() => FeedCubit(sl<FeedRepository>()));
  sl.registerFactory<CreatePostCubit>(
    () => CreatePostCubit(sl<FeedRepository>(), sl<PostTypeRepository>()),
  );

  // Profile.
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
  );
  sl.registerFactoryParam<UserProfileCubit, int, void>(
    (userId, _) => UserProfileCubit(sl<ProfileRepository>(), userId),
  );
  sl.registerFactory<BusinessDetailsCubit>(
    () => BusinessDetailsCubit(sl<ProfileRepository>()),
  );
  sl.registerFactory<BusinessProfileCubit>(
    () => BusinessProfileCubit(sl<ProfileRepository>(), sl<SubscriptionRepository>()),
  );

  // Business directory (/businesses).
  sl.registerLazySingleton<BusinessDirectoryDataSource>(
    () => BusinessDirectoryDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<BusinessDirectoryRepository>(
    () => BusinessDirectoryRepositoryImpl(sl<BusinessDirectoryDataSource>()),
  );

  // Orders (create only in current docs).
  sl.registerLazySingleton<OrdersRemoteDataSource>(
    () => OrdersRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<OrdersRepository>(
    () => OrdersRepositoryImpl(sl<OrdersRemoteDataSource>()),
  );

  // Notifications.
  sl.registerLazySingleton<NotificationsRemoteDataSource>(
    () => NotificationsRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<NotificationsRepository>(
    () => NotificationsRepositoryImpl(sl<NotificationsRemoteDataSource>()),
  );
  sl.registerFactory<NotificationsCubit>(
    () => NotificationsCubit(sl<NotificationsRepository>()),
  );
  // EditProfileCubit needs the current user, so it's built in the page, not here.

  // Chat (direct / group / broadcast).
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(sl<ChatRemoteDataSource>()),
  );
  sl.registerFactory<ChatListCubit>(() => ChatListCubit(sl<ChatRepository>()));
  sl.registerFactory<ChatLabelsCubit>(
      () => ChatLabelsCubit(sl<ChatRepository>()));
  sl.registerLazySingleton<UnreadCubit>(
      () => UnreadCubit(sl<ChatRepository>()));
  // ConversationCubit needs the selected Conversation, so it's built in the page.

  // Search (people).
  sl.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(sl<SearchRemoteDataSource>()),
  );
  sl.registerFactory<SearchCubit>(
    () => SearchCubit(sl<SearchRepository>(), sl<StorageManager>()),
  );

  // Offers.
  sl.registerLazySingleton<OffersRemoteDataSource>(
    () => OffersRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<OffersRepository>(
    () => OffersRepositoryImpl(sl<OffersRemoteDataSource>()),
  );
  sl.registerFactory<OffersListCubit>(() => OffersListCubit(sl<OffersRepository>()));
  // MakeOfferCubit needs the load id, so it's built in the sheet.

  // Wallet.
  sl.registerLazySingleton<WalletRemoteDataSource>(
    () => WalletRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(sl<WalletRemoteDataSource>()),
  );
  sl.registerFactory<WalletCubit>(() => WalletCubit(sl<WalletRepository>()));
  sl.registerFactory<TransactionsCubit>(
    () => TransactionsCubit(sl<WalletRepository>()),
  );

  // Admin.
  sl.registerLazySingleton<AdminRemoteDataSource>(
    () => AdminRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AdminRepository>(
    () => AdminRepositoryImpl(sl<AdminRemoteDataSource>()),
  );
  sl.registerFactory<AdminReportsCubit>(
    () => AdminReportsCubit(sl<AdminRepository>()),
  );
  sl.registerFactory<AdminUsersCubit>(
    () => AdminUsersCubit(sl<AdminRepository>()),
  );
  sl.registerLazySingleton<AdminWalletRemoteDataSource>(
    () => AdminWalletRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AdminWalletRepository>(
    () => AdminWalletRepositoryImpl(sl<AdminWalletRemoteDataSource>()),
  );
  sl.registerFactory<AdminPackagesCubit>(
    () => AdminPackagesCubit(sl<AdminWalletRepository>()),
  );
  sl.registerFactory<AdminWalletSettingsCubit>(
    () => AdminWalletSettingsCubit(sl<AdminWalletRepository>()),
  );

  // Subscription.
  sl.registerLazySingleton<SubscriptionRemoteDataSource>(
    () => SubscriptionRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(sl<SubscriptionRemoteDataSource>()),
  );
  sl.registerFactory<SubscriptionCubit>(
    () => SubscriptionCubit(sl<SubscriptionRepository>()),
  );
  sl.registerLazySingleton<AdminSubscriptionRemoteDataSource>(
    () => AdminSubscriptionRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<AdminSubscriptionRepository>(
    () => AdminSubscriptionRepositoryImpl(sl<AdminSubscriptionRemoteDataSource>()),
  );
  sl.registerFactory<AdminSubRequestsCubit>(
    () => AdminSubRequestsCubit(sl<AdminSubscriptionRepository>()),
  );
  sl.registerFactory<AdminSubPlansCubit>(
    () => AdminSubPlansCubit(sl<AdminSubscriptionRepository>()),
  );

  // Tags.
  sl.registerLazySingleton<TagRemoteDataSource>(
    () => TagRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<TagRepository>(
    () => TagRepositoryImpl(sl<TagRemoteDataSource>()),
  );
  sl.registerFactory<AdminTagsCubit>(
    () => AdminTagsCubit(sl<TagRepository>()),
  );

  // Groups.
  sl.registerLazySingleton<GroupsRemoteDataSource>(
    () => GroupsRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<GroupsRepository>(
    () => GroupsRepositoryImpl(sl<GroupsRemoteDataSource>()),
  );
  sl.registerFactory<GroupsListCubit>(() => GroupsListCubit(sl<GroupsRepository>()));
  sl.registerFactoryParam<GroupDetailCubit, int, void>(
    (groupId, _) => GroupDetailCubit(sl<GroupsRepository>(), groupId),
  );

  // Security (chat PIN).
  sl.registerLazySingleton<SecurityRemoteDataSource>(
    () => SecurityRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<SecurityRepository>(
    () => SecurityRepositoryImpl(sl<SecurityRemoteDataSource>()),
  );
  sl.registerFactory<SecurityCubit>(() => SecurityCubit(sl<SecurityRepository>()));

  // Contact sync (Module 8).
  sl.registerLazySingleton<ContactsDataSource>(() => const ContactsDataSourceImpl());
  sl.registerLazySingleton<ContactsRepository>(
    () => ContactsRepositoryImpl(sl<ContactsDataSource>()),
  );
  sl.registerFactory<ContactSyncCubit>(
    () => ContactSyncCubit(sl<ContactsRepository>()),
  );

  // Broadcasts.
  sl.registerLazySingleton<BroadcastsRemoteDataSource>(
    () => BroadcastsRemoteDataSourceImpl(sl<ApiClient>()),
  );
  sl.registerLazySingleton<BroadcastsRepository>(
    () => BroadcastsRepositoryImpl(sl<BroadcastsRemoteDataSource>()),
  );
  sl.registerFactory<CreateBroadcastCubit>(
    () => CreateBroadcastCubit(sl<BroadcastsRepository>(), sl<SearchRepository>()),
  );
}
