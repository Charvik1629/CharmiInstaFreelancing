import '../../../core/storage/storage_manager.dart';

/// Local, per-account tour progress. Approval changes do not restart the tour.
class AppTourProgress {
  const AppTourProgress(this._storage);
  final StorageManager _storage;

  bool hasSeen(int userId) =>
      _storage.getBool('app_tour_v1_$userId') ||
      // Preserve completed/skipped tours from the previous stage-based keys.
      _storage.getBool('app_tour_v1_${userId}_pending') ||
      _storage.getBool('app_tour_v1_${userId}_approved');

  Future<void> markDone(int userId) async {
    await _storage.setBool('app_tour_v1_$userId', value: true);
  }
}
