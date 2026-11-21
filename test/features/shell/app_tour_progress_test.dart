import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:charmi_insta_freelancing/core/storage/storage_manager.dart';
import 'package:charmi_insta_freelancing/features/shell/presentation/app_tour_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<StorageManager> storage() async => StorageManager(
    const FlutterSecureStorage(),
    await SharedPreferences.getInstance(),
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  test(
    'tour completion persists across instances and is scoped to account',
    () async {
      final progress = AppTourProgress(await storage());
      expect(progress.hasSeen(10), isFalse);
      await progress.markDone(10);
      final afterRestart = AppTourProgress(await storage());
      expect(afterRestart.hasSeen(10), isTrue);
      expect(afterRestart.hasSeen(11), isFalse);
    },
  );
  test('logout does not reset completed tour', () async {
    final store = await storage();
    await AppTourProgress(store).markDone(10);
    await store.clearSession();
    expect(AppTourProgress(await storage()).hasSeen(10), isTrue);
  });
  for (final stage in ['pending', 'approved']) {
    test(
      'legacy $stage completion prevents another tour after upgrade/approval',
      () async {
        SharedPreferences.setMockInitialValues({'app_tour_v1_10_$stage': true});
        expect(AppTourProgress(await storage()).hasSeen(10), isTrue);
        expect(AppTourProgress(await storage()).hasSeen(11), isFalse);
      },
    );
  }
}
