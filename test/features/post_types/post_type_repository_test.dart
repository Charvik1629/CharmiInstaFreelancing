import 'package:flutter_test/flutter_test.dart';
import 'package:charmi_insta_freelancing/core/config/app_config.dart';
import 'package:charmi_insta_freelancing/core/error/app_exception.dart';
import 'package:charmi_insta_freelancing/core/error/failure.dart';
import 'package:charmi_insta_freelancing/core/models/post_type.dart';
import 'package:charmi_insta_freelancing/features/post_types/data/datasources/post_type_remote_data_source.dart';
import 'package:charmi_insta_freelancing/features/post_types/data/repositories/post_type_repository_impl.dart';

class _FakeDataSource implements PostTypeRemoteDataSource {
  _FakeDataSource({this.result, this.error});
  final List<PostType>? result;
  final Object? error;

  @override
  Future<List<PostType>> getPostTypes() async {
    if (error != null) throw error!;
    return result ?? const [];
  }
}

void main() {
  final original = AppConfig.current;

  setUp(() {
    AppConfig.current = AppConfig.dev.copyWith(baseUrl: 'https://api.test');
  });
  tearDown(() => AppConfig.current = original);

  test('returns parsed list on success', () async {
    final repo = PostTypeRepositoryImpl(
      _FakeDataSource(result: const [PostType(id: 1, slug: 'buy', name: 'Buy')]),
    );
    final res = await repo.getPostTypes();
    expect(res.isSuccess, isTrue);
    expect(res.valueOrNull!.single.slug, 'buy');
  });

  test('maps a 401 AppException to AuthFailure', () async {
    final repo = PostTypeRepositoryImpl(
      _FakeDataSource(error: const AppException('nope', statusCode: 401)),
    );
    final res = await repo.getPostTypes();
    expect(res.failureOrNull, isA<AuthFailure>());
  });

  test('short-circuits with ConfigFailure when base URL is a placeholder', () async {
    AppConfig.current = original; // placeholder dev config
    final repo = PostTypeRepositoryImpl(_FakeDataSource(result: const []));
    final res = await repo.getPostTypes();
    expect(res.failureOrNull, isA<ConfigFailure>());
  });
}
