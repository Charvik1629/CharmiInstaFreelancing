import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// Admin wallet economy settings (`GET/PUT /admin/wallet/settings`). Costs are in
/// credits. Broadcast free limits/periods and demo top-up are included for
/// completeness; the pricing screen edits the core costs.
class WalletSettings extends Equatable {
  const WalletSettings({
    this.postCreditCost = 0,
    this.boostCreditCost = 0,
    this.boostDurationHours = 0,
    this.businessBoostCreditCost = 0,
    this.broadcastCreditCost = 0,
    this.broadcastListFreeLimit = 0,
    this.broadcastListPeriod = 'monthly',
    this.broadcastMessageFreeLimit = 0,
    this.broadcastMessagePeriod = 'monthly',
    this.broadcastMessageCreditCost = 0,
    this.currency = 'INR',
    this.demoTopupEnabled = false,
  });

  final int postCreditCost;
  final int boostCreditCost;
  final int boostDurationHours;
  final int businessBoostCreditCost;
  final int broadcastCreditCost;
  final int broadcastListFreeLimit;
  final String broadcastListPeriod;
  final int broadcastMessageFreeLimit;
  final String broadcastMessagePeriod;
  final int broadcastMessageCreditCost;
  final String currency;
  final bool demoTopupEnabled;

  factory WalletSettings.fromJson(Map<String, dynamic> json) => WalletSettings(
        postCreditCost: json.asIntOr('post_credit_cost', 0),
        boostCreditCost: json.asIntOr('boost_credit_cost', 0),
        boostDurationHours: json.asIntOr('boost_duration_hours', 0),
        businessBoostCreditCost: json.asIntOr('business_boost_credit_cost', 0),
        broadcastCreditCost: json.asIntOr('broadcast_credit_cost', 0),
        broadcastListFreeLimit: json.asIntOr('broadcast_list_free_limit', 0),
        broadcastListPeriod:
            json.asStringOr('broadcast_list_period', 'monthly'),
        broadcastMessageFreeLimit:
            json.asIntOr('broadcast_message_free_limit', 0),
        broadcastMessagePeriod:
            json.asStringOr('broadcast_message_period', 'monthly'),
        broadcastMessageCreditCost:
            json.asIntOr('broadcast_message_credit_cost', 0),
        currency: json.asStringOr('currency', 'INR'),
        demoTopupEnabled: json.asBool('demo_topup_enabled'),
      );

  WalletSettings copyWith({
    int? postCreditCost,
    int? boostCreditCost,
    int? boostDurationHours,
    int? businessBoostCreditCost,
    int? broadcastCreditCost,
    int? broadcastListFreeLimit,
    String? broadcastListPeriod,
    int? broadcastMessageFreeLimit,
    String? broadcastMessagePeriod,
    int? broadcastMessageCreditCost,
    bool? demoTopupEnabled,
  }) {
    return WalletSettings(
      postCreditCost: postCreditCost ?? this.postCreditCost,
      boostCreditCost: boostCreditCost ?? this.boostCreditCost,
      boostDurationHours: boostDurationHours ?? this.boostDurationHours,
      businessBoostCreditCost:
          businessBoostCreditCost ?? this.businessBoostCreditCost,
      broadcastCreditCost: broadcastCreditCost ?? this.broadcastCreditCost,
      broadcastListFreeLimit:
          broadcastListFreeLimit ?? this.broadcastListFreeLimit,
      broadcastListPeriod: broadcastListPeriod ?? this.broadcastListPeriod,
      broadcastMessageFreeLimit:
          broadcastMessageFreeLimit ?? this.broadcastMessageFreeLimit,
      broadcastMessagePeriod:
          broadcastMessagePeriod ?? this.broadcastMessagePeriod,
      broadcastMessageCreditCost:
          broadcastMessageCreditCost ?? this.broadcastMessageCreditCost,
      currency: currency,
      demoTopupEnabled: demoTopupEnabled ?? this.demoTopupEnabled,
    );
  }

  @override
  List<Object?> get props => [
        postCreditCost,
        boostCreditCost,
        boostDurationHours,
        businessBoostCreditCost,
        broadcastCreditCost,
        broadcastListFreeLimit,
        broadcastListPeriod,
        broadcastMessageFreeLimit,
        broadcastMessagePeriod,
        broadcastMessageCreditCost,
        currency,
        demoTopupEnabled,
      ];
}
