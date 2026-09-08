/// The editable fields of a profile (POST /profile). All optional — only the
/// provided fields are sent. [avatarPath]/[logoPath] are local files to upload.
///
/// The core fields (name/bio/phone/avatar) are accepted by the API today; the
/// business-details fields below are wired per the documented `POST /profile`
/// extension (BACKEND_REQUIREMENTS B1) and persist the moment the backend adds
/// them — until then the backend ignores the extra keys.
class ProfileUpdate {
  const ProfileUpdate({
    this.name,
    this.bio,
    this.phone,
    this.avatarPath,
    // Business details
    this.businessName,
    this.companyType,
    this.msmeNumber,
    this.website,
    this.description,
    this.association,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.products,
    this.tagIds,
    this.socialLinks,
    this.logoPath,
  });

  final String? name;
  final String? bio;
  final String? phone;
  final String? avatarPath;

  final String? businessName;
  final String? companyType;
  final String? msmeNumber;
  final String? website;
  final String? description;
  final String? association;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final List<String>? products;
  final List<int>? tagIds;
  final Map<String, String>? socialLinks;
  final String? logoPath;

  bool get hasAvatar => avatarPath != null && avatarPath!.isNotEmpty;
  bool get hasLogo => logoPath != null && logoPath!.isNotEmpty;

  /// True when there is at least one thing to send.
  bool get isEmpty =>
      name == null &&
      bio == null &&
      phone == null &&
      !hasAvatar &&
      !hasLogo &&
      businessName == null &&
      companyType == null &&
      msmeNumber == null &&
      website == null &&
      description == null &&
      association == null &&
      address == null &&
      city == null &&
      state == null &&
      pincode == null &&
      (products == null || products!.isEmpty) &&
      (tagIds == null || tagIds!.isEmpty) &&
      (socialLinks == null || socialLinks!.isEmpty);
}
