/// Pagination metadata from list endpoints (`meta` object).
///
/// The API is inconsistent across sections: some return
/// `{ current_page, total }`, others also include `last_page` / `per_page`.
/// All are optional here and parsed defensively.
class PaginationMeta {
  const PaginationMeta({
    required this.currentPage,
    this.lastPage,
    this.perPage,
    this.total,
  });

  final int currentPage;
  final int? lastPage;
  final int? perPage;
  final int? total;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: _asInt(json['current_page']) ?? 1,
      lastPage: _asInt(json['last_page']),
      perPage: _asInt(json['per_page']),
      total: _asInt(json['total']),
    );
  }

  /// Whether another page likely exists. Uses `last_page` when present,
  /// otherwise infers from `total`/`per_page`, otherwise assumes the caller
  /// checks the returned item count.
  bool get hasMore {
    if (lastPage != null) return currentPage < lastPage!;
    if (total != null && perPage != null && perPage! > 0) {
      return currentPage * perPage! < total!;
    }
    return true;
  }

  static int? _asInt(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
}

/// A parsed list response: the items plus its pagination meta.
class PaginatedResponse<T> {
  const PaginatedResponse({required this.items, required this.meta});

  final List<T> items;
  final PaginationMeta meta;
}

/// Decodes the API's response envelope. Every endpoint wraps its payload in a
/// top-level `data` field; list endpoints also carry `meta`. These helpers
/// centralize that unwrapping so datasources don't repeat it.
class ApiEnvelope {
  ApiEnvelope._();

  /// Extracts a single object of type [T] from `{ "data": { ... } }`.
  static T object<T>(
    Object? body,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final map = _asMap(body);
    final data = map['data'];
    if (data is Map<String, dynamic>) return fromJson(data);
    // Some endpoints (rarely) return the object un-wrapped.
    return fromJson(map);
  }

  /// Extracts a list + pagination meta from `{ "data": [...], "meta": {...} }`.
  static PaginatedResponse<T> list<T>(
    Object? body,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final map = _asMap(body);
    final rawList = map['data'];
    final items = <T>[];
    if (rawList is List) {
      for (final e in rawList) {
        if (e is Map<String, dynamic>) items.add(fromJson(e));
      }
    }
    final meta = map['meta'] is Map<String, dynamic>
        ? PaginationMeta.fromJson(map['meta'] as Map<String, dynamic>)
        : const PaginationMeta(currentPage: 1);
    return PaginatedResponse(items: items, meta: meta);
  }

  static Map<String, dynamic> _asMap(Object? body) =>
      body is Map<String, dynamic> ? body : <String, dynamic>{};
}
