import 'package:equatable/equatable.dart';

import '../extensions/json_extensions.dart';

/// The authenticated user (from /auth/me, /profile). Roles drive capability
/// gating across the app: `user` (browse), `creator` (post/sell), `admin`.
class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    this.username,
    this.shareUrl,
    this.email,
    this.avatarUrl,
    this.bio,
    this.phone,
    this.businessName,
    this.approvalStatus = 'approved',
    this.gstNumber,
    this.panNumber,
    this.aadhaarNumber,
    this.referralCode,
    this.roles = const [],
    this.creditBalance = 0,
    this.postsCount = 0,
    this.isVerified = false,
    this.isPremium = false,
    this.lastSeenAt,
    this.capabilities = const {},
    this.businessDetailsComplete,
    this.businessDetailsMissing = const [],
    this.businessDetailsRequiredFields = const [],
    this.businessDetails = const {},
  });

  final Map<String, bool> capabilities;
  final bool? businessDetailsComplete;
  final List<String> businessDetailsMissing;
  final List<String> businessDetailsRequiredFields;
  final Map<String, dynamic> businessDetails;

  bool capability(String key, {bool fallback = true}) =>
      !isRejected && (capabilities[key] ?? fallback);
  bool get canBrowse => capability('can_browse');
  bool get canUpdateBusiness => capability('can_update_business');
  bool get canChat => !isPending && capability('can_chat');
  bool get canAsk => !isPending && capability('can_ask');
  bool get canOffer => !isPending && capability('can_offer');
  bool get needsBusinessDetails => businessDetailsComplete == false;

  static const businessKeys = [
    'company_type',
    'msme_number',
    'association',
    'website',
    'address',
    'city',
    'state',
    'pincode',
    'description',
    'products',
    'tags',
    'social_links',
    'logo_url',
  ];

  final int id;
  final String name;

  /// Public handle (e.g. `bob`) — used for the profile deep link / share URL.
  final String? username;

  /// Canonical shareable profile URL (server-provided `share_url`).
  final String? shareUrl;

  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String? phone;

  /// Registered business / firm name (B2B accounts).
  final String? businessName;

  /// Super-admin gate: `pending`, `approved`, or `rejected`. New accounts start
  /// `pending` can log in with restricted capabilities; rejected stays blocked.
  final String approvalStatus;

  final String? gstNumber;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? referralCode;

  final List<String> roles;
  final int creditBalance;

  /// Number of non-deleted posts (loads) — from `/auth/me` `posts_count`.
  final int postsCount;

  /// Verified badge (admin-approved) and premium subscription state — from the
  /// public profile (`is_verified` / `is_premium`).
  final bool isVerified;
  final bool isPremium;
  final DateTime? lastSeenAt;

  bool get isCreator => roles.contains('creator');
  bool get isAdmin => roles.contains('admin');

  /// A business account (shows the "Business" chip). The public profile omits
  /// business fields, so this is only known for the current user.
  bool get isBusiness =>
      (businessName ?? '').isNotEmpty || roles.contains('business');

  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  /// Anyone who can create posts / receive payments (creator or admin).
  bool get canPost =>
      !isPending &&
      capability('can_create_post', fallback: isCreator || isAdmin);

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json.asIntOr('id', 0),
    name: json.asStringOr('name', ''),
    username: json.asString('username'),
    shareUrl: json.asString('share_url'),
    email: json.asString('email'),
    avatarUrl: json.asString('avatar_url'),
    bio: json.asString('bio'),
    phone: json.asString('phone'),
    businessName: json.asString('business_name'),
    approvalStatus: json.asStringOr('approval_status', 'approved'),
    gstNumber: json.asString('gst_number'),
    panNumber: json.asString('pan_number'),
    aadhaarNumber: json.asString('aadhaar_number'),
    referralCode: json.asString('referral_code'),
    roles: json.asStringList('roles'),
    creditBalance: json.asIntOr('credit_balance', 0),
    postsCount: json.asIntOr('posts_count', 0),
    isVerified: json.asBool('is_verified'),
    isPremium: json.asBool('is_premium'),
    lastSeenAt: json.asDate('last_seen_at'),
    capabilities: {
      for (final entry in (json.asMap('capabilities') ?? {}).entries)
        entry.key: {'value': entry.value}.asBool('value'),
    },
    businessDetailsComplete: json['business_details_complete'] == null
        ? null
        : json.asBool('business_details_complete'),
    businessDetailsMissing: json.asStringList('business_details_missing'),
    businessDetailsRequiredFields: json.asStringList(
      'business_details_required_fields',
    ),
    businessDetails: {
      for (final key in businessKeys)
        if (json.containsKey(key)) key: json[key],
    },
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'share_url': shareUrl,
    'email': email,
    'avatar_url': avatarUrl,
    'bio': bio,
    'phone': phone,
    'business_name': businessName,
    'approval_status': approvalStatus,
    'gst_number': gstNumber,
    'pan_number': panNumber,
    'aadhaar_number': aadhaarNumber,
    'referral_code': referralCode,
    'roles': roles,
    'credit_balance': creditBalance,
    'posts_count': postsCount,
    'is_verified': isVerified,
    'is_premium': isPremium,
    'last_seen_at': lastSeenAt?.toIso8601String(),
    'capabilities': capabilities,
    if (businessDetailsComplete != null)
      'business_details_complete': businessDetailsComplete,
    'business_details_missing': businessDetailsMissing,
    'business_details_required_fields': businessDetailsRequiredFields,
    ...businessDetails,
  };

  User copyWith({
    String? name,
    String? username,
    String? shareUrl,
    String? email,
    String? avatarUrl,
    String? bio,
    String? phone,
    String? businessName,
    String? approvalStatus,
    String? gstNumber,
    String? panNumber,
    String? aadhaarNumber,
    String? referralCode,
    List<String>? roles,
    int? creditBalance,
    int? postsCount,
    bool? isVerified,
    bool? isPremium,
    DateTime? lastSeenAt,
    Map<String, bool>? capabilities,
    bool? businessDetailsComplete,
    List<String>? businessDetailsMissing,
    List<String>? businessDetailsRequiredFields,
    Map<String, dynamic>? businessDetails,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      shareUrl: shareUrl ?? this.shareUrl,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      referralCode: referralCode ?? this.referralCode,
      roles: roles ?? this.roles,
      creditBalance: creditBalance ?? this.creditBalance,
      postsCount: postsCount ?? this.postsCount,
      isVerified: isVerified ?? this.isVerified,
      isPremium: isPremium ?? this.isPremium,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      capabilities: capabilities ?? this.capabilities,
      businessDetailsComplete:
          businessDetailsComplete ?? this.businessDetailsComplete,
      businessDetailsMissing:
          businessDetailsMissing ?? this.businessDetailsMissing,
      businessDetailsRequiredFields:
          businessDetailsRequiredFields ?? this.businessDetailsRequiredFields,
      businessDetails: businessDetails ?? this.businessDetails,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    username,
    shareUrl,
    email,
    avatarUrl,
    bio,
    phone,
    businessName,
    approvalStatus,
    gstNumber,
    panNumber,
    aadhaarNumber,
    referralCode,
    roles,
    creditBalance,
    postsCount,
    isVerified,
    isPremium,
    lastSeenAt,
    capabilities,
    businessDetailsComplete,
    businessDetailsMissing,
    businessDetailsRequiredFields,
    businessDetails,
  ];
}
