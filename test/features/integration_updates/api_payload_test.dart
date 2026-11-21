import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/network/api_client.dart';
import 'package:charmi_insta_freelancing/core/models/post_location.dart';
import 'package:charmi_insta_freelancing/features/feed/data/datasources/feed_remote_data_source.dart';
import 'package:charmi_insta_freelancing/features/feed/domain/entities/new_post.dart';
import 'package:charmi_insta_freelancing/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:charmi_insta_freelancing/features/profile/domain/entities/profile_update.dart';
import 'package:charmi_insta_freelancing/features/chat/data/datasources/chat_remote_data_source.dart';

class _Adapter implements HttpClientAdapter {
  late RequestOptions request;
  String wireBody = '';
  Map<String, dynamic> response = {
    'data': {'id': 1, 'name': 'Example', 'title': 'Post'},
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      final bytes = await requestStream.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      wireBody = utf8.decode(bytes, allowMalformed: true);
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late ApiClient client;
  setUp(() {
    adapter = _Adapter();
    client = ApiClient(
      Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter,
    );
  });
  test(
    'post location is transmitted as paired coordinates and cleared explicitly',
    () async {
      final remote = FeedRemoteDataSourceImpl(client);
      await remote.createLoad(
        const NewPost(
          title: 'Post',
          location: PostLocation(0, 0, label: 'Port'),
        ),
      );
      expect(adapter.request.data['location_lat'], 0);
      expect(adapter.request.data['location_lng'], 0);
      expect(adapter.request.data['location_label'], 'Port');
      await remote.updateLoad(
        1,
        const NewPost(title: 'Post', clearLocation: true),
      );
      expect(adapter.request.data['clear_location'], true);
      expect(adapter.request.data.containsKey('location_lat'), isFalse);
    },
  );
  test(
    'business completion request sends require_complete and nested social map',
    () async {
      await ProfileRemoteDataSourceImpl(client).updateProfile(
        const ProfileUpdate(
          requireComplete: true,
          name: 'Example',
          socialLinks: {'instagram': 'https://instagram.com/example'},
        ),
      );
      expect(adapter.request.data['require_complete'], true);
      expect(adapter.request.data['social_links'], {
        'instagram': 'https://instagram.com/example',
      });
    },
  );
  test(
    'shared endpoint requests correct tab/page and decodes server totals',
    () async {
      adapter.response = {
        'data': {
          'media_count': 8,
          'links_count': 6,
          'documents_count': 4,
          'items': [],
        },
        'meta': {'current_page': 2, 'last_page': 2, 'total': 6},
      };
      final result = await ChatRemoteDataSourceImpl(client)
          .getShared(99, type: 'links', page: 2);
      expect(adapter.request.path, '/conversations/99/shared');
      expect(adapter.request.queryParameters, {
        'type': 'links',
        'page': 2,
        'per_page': 20,
      });
      expect(result.linksCount, 6);
      expect(result.meta.hasMore, isFalse);
    },
  );
  test(
    'multipart profile completion and location clearing use form-safe booleans',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'nexveero-contract-',
      );
      final file = File('${directory.path}/photo.png')
        ..writeAsBytesSync([1, 2, 3]);
      try {
        await ProfileRemoteDataSourceImpl(client).updateProfile(
          ProfileUpdate(
            requireComplete: true,
            name: 'Example',
            logoPath: file.path,
          ),
        );
        expect(
          (adapter.request.data as FormData).fields.any(
            (entry) => entry.key == 'require_complete' && entry.value == '1',
          ),
          isTrue,
        );
        await FeedRemoteDataSourceImpl(client).updateLoad(
          1,
          NewPost(title: 'Post', clearLocation: true, imagePaths: [file.path]),
        );
        expect(
          (adapter.request.data as FormData).fields.any(
            (entry) => entry.key == 'clear_location' && entry.value == '1',
          ),
          isTrue,
        );
      } finally {
        directory.deleteSync(recursive: true);
      }
    },
  );

  for (final upload in ['none', 'logo', 'avatar']) {
    for (final count in [1, 2]) {
      test(
        'profile $upload upload preserves $count products/tags on the wire',
        () async {
          final directory = Directory.systemTemp.createTempSync(
            'nexveero-array-contract-',
          );
          final file = File('${directory.path}/photo.png')
            ..writeAsBytesSync([1, 2, 3]);
          final products = ['Container', 'Refrigerated'].take(count).toList();
          final tags = [3, 8].take(count).toList();
          try {
            await ProfileRemoteDataSourceImpl(client).updateProfile(
              ProfileUpdate(
                requireComplete: true,
                name: 'Example',
                products: products,
                tagIds: tags,
                socialLinks: const {
                  'instagram': 'https://instagram.com/example',
                },
                logoPath: upload == 'logo' ? file.path : null,
                avatarPath: upload == 'avatar' ? file.path : null,
              ),
            );
            if (upload == 'none') {
              expect(adapter.request.contentType, Headers.jsonContentType);
              final json = jsonDecode(adapter.wireBody) as Map<String, dynamic>;
              expect(json['products'], products);
              expect(json['tag_ids'], tags);
              expect(json['social_links'], {
                'instagram': 'https://instagram.com/example',
              });
            } else {
              final body = adapter.request.data as FormData;
              expect(
                body.fields
                    .where((entry) => entry.key == 'products[]')
                    .map((entry) => entry.value),
                products,
              );
              expect(
                body.fields
                    .where((entry) => entry.key == 'tag_ids[]')
                    .map((entry) => entry.value),
                tags.map((id) => '$id'),
              );
              expect(
                body.fields.any(
                  (entry) => entry.key == 'products' || entry.key == 'tag_ids',
                ),
                isFalse,
              );
              expect(adapter.wireBody, contains('name="products[]"'));
              expect(adapter.wireBody, contains('name="tag_ids[]"'));
              expect(
                adapter.wireBody,
                contains('name="social_links[instagram]"'),
              );
              expect(body.files.single.key, upload);
              expect(
                body.fields.any(
                  (entry) =>
                      entry.key == 'require_complete' && entry.value == '1',
                ),
                isTrue,
              );
            }
          } finally {
            directory.deleteSync(recursive: true);
          }
        },
      );
    }
  }
}
