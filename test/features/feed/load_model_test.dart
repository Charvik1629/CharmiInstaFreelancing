import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/models/load.dart';

void main() {
  final full = {
    'id': 1,
    'title': 'Need flatbed Mumbai → Delhi',
    'body': 'Pickup tomorrow',
    'media_url': '/media/loads/abc.jpg',
    'media_mime': 'image/jpeg',
    'media_kind': 'image',
    'status': 'active',
    'is_boosted': true,
    'is_business': false,
    'post_type': {'id': 2, 'slug': 'sell', 'name': 'Sell'},
    'author': {'id': 2, 'name': 'Alice', 'avatar_url': null},
    'is_own': false,
    'can_message': true,
    'can_report': true,
    'viewer_has_requested': false,
    'conversation_id': null,
    'created_at': '2026-07-31T06:00:00+00:00',
  };

  test('parses a full feed item', () {
    final l = Load.fromJson(full);
    expect(l.id, 1);
    expect(l.postType!.slug, 'sell');
    expect(l.author!.name, 'Alice');
    expect(l.mediaKind, MediaKind.image);
    expect(l.hasImage, isTrue);
    expect(l.canMessage, isTrue);
    expect(l.isBoosted, isTrue);
  });

  test('missing media → MediaKind.none, hasImage false', () {
    final l = Load.fromJson({'id': 2, 'title': 'text only'});
    expect(l.mediaKind, MediaKind.none);
    expect(l.hasImage, isFalse);
    expect(l.hasFile, isFalse);
  });

  test('file media detected', () {
    final l = Load.fromJson({'id': 3, 'title': 'doc', 'media_url': '/x.pdf', 'media_kind': 'file'});
    expect(l.hasFile, isTrue);
    expect(l.hasImage, isFalse);
  });

  test('null post_type / author tolerated', () {
    final l = Load.fromJson({'id': 4, 'title': 'x'});
    expect(l.postType, isNull);
    expect(l.author, isNull);
  });

  test('copyWith flips viewerHasRequested and keeps identity', () {
    final l = Load.fromJson(full);
    final r = l.copyWith(viewerHasRequested: true, conversationId: 5);
    expect(r.id, l.id);
    expect(r.viewerHasRequested, isTrue);
    expect(r.conversationId, 5);
  });
}
