import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:charmi_insta_freelancing/core/storage/storage_keys.dart';
import 'package:charmi_insta_freelancing/core/storage/storage_manager.dart';
import 'package:charmi_insta_freelancing/features/auth/data/datasources/auth_remote_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'installation identity survives logout and differs on another device',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final first = await StorageManager.create();
      await AuthRemoteDataSourceImpl.initializeInstallation(first);
      final id = first.getString(StorageKeys.installationId);
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      await first.clearSession();
      await AuthRemoteDataSourceImpl.initializeInstallation(first);
      expect(first.getString(StorageKeys.installationId), id);
      SharedPreferences.setMockInitialValues({});
      final second = await StorageManager.create();
      await AuthRemoteDataSourceImpl.initializeInstallation(second);
      expect(second.getString(StorageKeys.installationId), isNot(id));
    },
  );
}
