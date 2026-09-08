import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/models/post_type.dart';
import 'package:charmi_insta_freelancing/core/models/author.dart';
import 'package:charmi_insta_freelancing/core/models/user.dart';

void main() {
  group('PostType', () {
    test('parses full JSON', () {
      final pt = PostType.fromJson({
        'id': 2,
        'slug': 'sell',
        'name': 'Sell',
        'description': 'Offer a load',
        'is_active': true,
        'sort_order': 2,
      });
      expect(pt.id, 2);
      expect(pt.slug, 'sell');
      expect(pt.sortOrder, 2);
    });

    test('handles missing/blank fields with safe defaults', () {
      final pt = PostType.fromJson(<String, dynamic>{});
      expect(pt.id, 0);
      expect(pt.slug, '');
      expect(pt.isActive, isTrue);
      expect(pt.sortOrder, isNull);
    });

    test('parses numeric id given as string', () {
      final pt = PostType.fromJson({'id': '3', 'slug': 'business', 'name': 'Business'});
      expect(pt.id, 3);
    });

    test('round-trips through toJson', () {
      const pt = PostType(id: 1, slug: 'buy', name: 'Buy', sortOrder: 1);
      expect(PostType.fromJson(pt.toJson()), pt);
    });
  });

  group('Author', () {
    test('parses avatar and last_seen', () {
      final a = Author.fromJson({
        'id': 2,
        'name': 'Alice',
        'avatar_url': '/media/a.jpg',
        'last_seen_at': '2026-07-31T05:40:00+00:00',
      });
      expect(a.name, 'Alice');
      expect(a.avatarUrl, '/media/a.jpg');
      expect(a.lastSeenAt, isNotNull);
    });

    test('tolerates null avatar and bad date', () {
      final a = Author.fromJson({'id': 1, 'name': 'X', 'avatar_url': null, 'last_seen_at': 'not-a-date'});
      expect(a.avatarUrl, isNull);
      expect(a.lastSeenAt, isNull);
    });
  });

  group('User', () {
    test('parses roles and credit balance; role helpers work', () {
      final u = User.fromJson({
        'id': 2,
        'name': 'Alice',
        'email': 'a@b.co',
        'roles': ['creator'],
        'credit_balance': 90,
      });
      expect(u.creditBalance, 90);
      expect(u.isCreator, isTrue);
      expect(u.isAdmin, isFalse);
      expect(u.canPost, isTrue);
    });

    test('plain user cannot post', () {
      final u = User.fromJson({'id': 1, 'name': 'Bob', 'roles': ['user']});
      expect(u.canPost, isFalse);
    });

    test('missing roles yields empty list, not crash', () {
      final u = User.fromJson({'id': 1, 'name': 'Bob'});
      expect(u.roles, isEmpty);
      expect(u.creditBalance, 0);
    });

    test('copyWith preserves id and overrides fields', () {
      final u = User.fromJson({'id': 5, 'name': 'A', 'credit_balance': 10});
      final u2 = u.copyWith(creditBalance: 20, name: 'B');
      expect(u2.id, 5);
      expect(u2.name, 'B');
      expect(u2.creditBalance, 20);
    });
  });
}
