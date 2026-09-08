/// Defensive accessors for decoded JSON maps. APIs occasionally return numbers
/// as strings, nulls where objects are expected, etc. These helpers keep model
/// parsing terse and crash-free instead of repeating casts everywhere.
extension JsonReaderX on Map<String, dynamic> {
  int? asInt(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}');
  }

  int asIntOr(String key, int fallback) => asInt(key) ?? fallback;

  double? asDouble(String key) {
    final v = this[key];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}');
  }

  String? asString(String key) {
    final v = this[key];
    if (v == null) return null;
    return v is String ? v : '$v';
  }

  String asStringOr(String key, String fallback) => asString(key) ?? fallback;

  bool asBool(String key, {bool fallback = false}) {
    final v = this[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return fallback;
  }

  DateTime? asDate(String key) {
    final v = this[key];
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  List<String> asStringList(String key) {
    final v = this[key];
    if (v is List) return v.map((e) => '$e').toList();
    return const [];
  }

  Map<String, dynamic>? asMap(String key) {
    final v = this[key];
    return v is Map<String, dynamic> ? v : null;
  }

  List<Map<String, dynamic>> asMapList(String key) {
    final v = this[key];
    if (v is List) {
      return v.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}
