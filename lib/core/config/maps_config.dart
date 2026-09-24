/// Google Maps / Places configuration.
///
/// The same key is also referenced natively (Android manifest meta-data and iOS
/// AppDelegate) for the Maps SDK; this constant is used for the Static Maps and
/// Places REST calls. Restrict the key in Google Cloud (Android package + SHA-1,
/// iOS bundle id, and the enabled-APIs list) so shipping it in the app is safe.
class MapsConfig {
  MapsConfig._();

  static const String apiKey = 'AIzaSyA8aVN6jVSWsASd5Lc7qra4sNofCusVI6U';

  /// A WhatsApp-style static map thumbnail (marker at [lat],[lng]).
  static String staticMap(double lat, double lng,
      {int zoom = 15, int width = 600, int height = 300}) {
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$lat,$lng'
        '&zoom=$zoom'
        '&size=${width}x$height'
        '&scale=2'
        '&markers=color:red%7C$lat,$lng'
        '&key=$apiKey';
  }
}
