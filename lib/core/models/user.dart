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
    this.lastSeenAt,
  });

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
  /// `pending` and cannot log in (login returns 403) until an admin approves.
  final String approvalStatus;

  final String? gstNumber;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? referralCode;

  final List<String> roles;
  final int creditBalance;
  final DateTime? lastSeenAt;

  bool get isCreator => roles.contains('creator');
  bool get isAdmin => roles.contains('admin');

  bool get isApproved => approvalStatus == 'approved';
  bool get isPending => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  /// Anyone who can create posts / receive payments (creator or admin).
  bool get canPost => isCreator || isAdmin;

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
        lastSeenAt: json.asDate('last_seen_at'),
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
        'last_seen_at': lastSeenAt?.toIso8601String(),
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
    DateTime? lastSeenAt,
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
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
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
        lastSeenAt,
      ];
}
