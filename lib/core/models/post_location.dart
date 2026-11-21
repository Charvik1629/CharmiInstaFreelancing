import 'package:equatable/equatable.dart';

import '../extensions/json_extensions.dart';

class PostLocation extends Equatable {
  const PostLocation(this.lat, this.lng, {this.label});
  final double lat;
  final double lng;
  final String? label;

  static PostLocation? fromJson(Map<String, dynamic> json) {
    final lat = json.asDouble('location_lat'),
        lng = json.asDouble('location_lng');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return PostLocation(lat, lng, label: json.asString('location_label'));
  }

  Map<String, dynamic> toJson() => {
    'location_lat': lat,
    'location_lng': lng,
    if (label != null) 'location_label': label,
  };
  @override
  List<Object?> get props => [lat, lng, label];
}
