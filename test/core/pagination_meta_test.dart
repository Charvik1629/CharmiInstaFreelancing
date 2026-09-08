import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/network/api_response.dart';

void main() {
  group('PaginationMeta.fromJson', () {
    test('parses full meta and computes hasMore', () {
      final meta = PaginationMeta.fromJson(
        {'current_page': 1, 'last_page': 3, 'per_page': 20, 'total': 55},
      );
      expect(meta.currentPage, 1);
      expect(meta.lastPage, 3);
      expect(meta.hasMore, isTrue);
    });

    test('last page has no more', () {
      final meta = PaginationMeta.fromJson(
        {'current_page': 3, 'last_page': 3, 'per_page': 20, 'total': 55},
      );
      expect(meta.hasMore, isFalse);
    });

    test('infers hasMore from total/per_page when last_page missing', () {
      final more = PaginationMeta.fromJson(
        {'current_page': 1, 'per_page': 20, 'total': 40},
      );
      final done = PaginationMeta.fromJson(
        {'current_page': 2, 'per_page': 20, 'total': 40},
      );
      expect(more.hasMore, isTrue);
      expect(done.hasMore, isFalse);
    });

    test('defaults current_page to 1 and hasMore true when meta minimal', () {
      final meta = PaginationMeta.fromJson(<String, dynamic>{});
      expect(meta.currentPage, 1);
      expect(meta.hasMore, isTrue); // caller falls back to item-count check
    });

    test('parses numeric strings defensively', () {
      final meta = PaginationMeta.fromJson(
        {'current_page': '2', 'total': '30', 'per_page': '10'},
      );
      expect(meta.currentPage, 2);
      expect(meta.total, 30);
    });
  });
}
