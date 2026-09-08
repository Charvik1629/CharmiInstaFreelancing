import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device currently has a network transport. Used to fail
/// fast with a [NetworkFailure] instead of waiting for a socket timeout.
class NetworkInfo {
  NetworkInfo(this._connectivity);

  final Connectivity _connectivity;

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
