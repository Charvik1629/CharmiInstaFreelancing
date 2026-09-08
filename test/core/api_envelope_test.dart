import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/models/post_type.dart';
import 'package:charmi_insta_freelancing/core/network/api_response.dart';

void main() {
  group('ApiEnvelope.object', () {
    test('unwraps {data: {...}}', () {
      final pt = ApiEnvelope.object(
        {'data': {'id': 1, 'slug': 'buy', 'name': 'Buy'}},
        PostType.fromJson,
      );
      expect(pt.slug, 'buy');
    });

    test('falls back to unwrapped object', () {
      final pt = ApiEnvelope.object(
        {'id': 1, 'slug': 'buy', 'name': 'Buy'},
        PostType.fromJson,
      );
      expect(pt.slug, 'buy');
    });
  });

  group('ApiEnvelope.list', () {
    test('parses items and meta', () {
      final res = ApiEnvelope.list(
        {
          'data': [
            {'id': 1, 'slug': 'buy', 'name': 'Buy'},
            {'id': 2, 'slug': 'sell', 'name': 'Sell'},
          ],
          'meta': {'current_page': 1, 'last_page': 2},
        },
        PostType.fromJson,
      );
      expect(res.items.length, 2);
      expect(res.meta.hasMore, isTrue);
    });

    test('missing data yields empty list and default meta', () {
      final res = ApiEnvelope.list(<String, dynamic>{}, PostType.fromJson);
      expect(res.items, isEmpty);
      expect(res.meta.currentPage, 1);
    });

    test('skips non-object entries defensively', () {
      final res = ApiEnvelope.list(
        {'data': [null, 'garbage', {'id': 9, 'slug': 'x', 'name': 'X'}]},
        PostType.fromJson,
      );
      expect(res.items.length, 1);
      expect(res.items.first.id, 9);
    });

    test('non-map body does not throw', () {
      final res = ApiEnvelope.list('unexpected', PostType.fromJson);
      expect(res.items, isEmpty);
    });
  });
}
