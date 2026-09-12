import 'package:equatable/equatable.dart';

import '../../../../core/extensions/json_extensions.dart';

/// A business in the directory (`GET /businesses`). Distinct from a business
/// FEED post — this is the searchable directory of approved businesses.
class Business extends Equatable {
  const Business({
    required this.id,
    required this.name,
    this.businessName,
    this.companyType,
    this.logoUrl,
    this.description,
    this.website,
    this.city,
    this.state,
    this.products = const [],
    this.isVerified = false,
    this.isPremium = false,
    this.isBoosted = false,
    this.canBoost = false,
  });

  final int id;
  final String name;
  final String? businessName;
  final String? companyType;
  final String? logoUrl;
  final String? description;
  final String? website;
  final String? city;
  final String? state;
  final List<String> products;
  final bool isVerified;
  final bool isPremium;
  final bool isBoosted;
  final bool canBoost;

  String get location =>
      [city, state].where((s) => (s ?? '').isNotEmpty).join(', ');

  factory Business.fromJson(Map<String, dynamic> json) => Business(
        id: json.asIntOr('id', 0),
        name: json.asStringOr('name', 'Business'),
        businessName: json.asString('business_name'),
        companyType: json.asString('company_type'),
        logoUrl: json.asString('logo_url') ?? json.asString('avatar_url'),
        description: json.asString('description'),
        website: json.asString('website'),
        city: json.asString('city'),
        state: json.asString('state'),
        products: json.asStringList('products'),
        isVerified: json.asBool('is_verified'),
        isPremium: json.asBool('is_premium'),
        isBoosted: json.asBool('is_boosted'),
        canBoost: json.asBool('can_boost'),
      );

  Business copyWith({bool? isBoosted, bool? canBoost}) => Business(
        id: id,
        name: name,
        businessName: businessName,
        companyType: companyType,
        logoUrl: logoUrl,
        description: description,
        website: website,
        city: city,
        state: state,
        products: products,
        isVerified: isVerified,
        isPremium: isPremium,
        isBoosted: isBoosted ?? this.isBoosted,
        canBoost: canBoost ?? this.canBoost,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        businessName,
        companyType,
        logoUrl,
        description,
        website,
        city,
        state,
        products,
        isVerified,
        isPremium,
        isBoosted,
        canBoost,
      ];
}
