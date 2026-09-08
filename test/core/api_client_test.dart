import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/error/app_exception.dart';
import 'package:charmi_insta_freelancing/core/network/api_client.dart';

/// Stub adapter that returns a canned status + JSON body for any request, so we
/// can exercise ApiClient's DioException mapping without a real server.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body);
  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _clientReturning(int status, Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = _StubAdapter(status, body);
  return ApiClient(dio);
}

void main() {
  test('422 surfaces first field error as message and keeps fieldErrors', () async {
    final client = _clientReturning(422, {
      'message': 'The given data was invalid.',
      'errors': {
        'email': ['The email has already been taken.'],
      },
    });
    try {
      await client.get('/anything');
      fail('should have thrown');
    } on AppException catch (e) {
      expect(e.statusCode, 422);
      expect(e.message, 'The email has already been taken.');
      expect(e.fieldErrors?['email'], isNotEmpty);
    }
  });

  test('402 keeps the server message', () async {
    final client = _clientReturning(402, {
      'message': 'Insufficient credits. Posting costs 5 credits.',
    });
    try {
      await client.get('/loads');
      fail('should have thrown');
    } on AppException catch (e) {
      expect(e.statusCode, 402);
      expect(e.message, contains('Insufficient credits'));
    }
  });

  test('successful 200 returns the response body', () async {
    final client = _clientReturning(200, {'data': {'ok': true}});
    final res = await client.get<Map<String, dynamic>>('/ping');
    expect(res.statusCode, 200);
    expect((res.data!['data'] as Map)['ok'], isTrue);
  });
}
