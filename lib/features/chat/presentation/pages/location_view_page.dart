import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Full-screen map showing a shared location, opened when a location bubble is
/// tapped. "Open in Google Maps" hands off to the external maps app.
class LocationViewPage extends StatelessWidget {
  const LocationViewPage(
      {super.key, required this.lat, required this.lng, this.label});

  final double lat;
  final double lng;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final target = LatLng(lat, lng);
    return Scaffold(
      appBar: AppBar(title: Text(label?.isNotEmpty == true ? label! : 'Location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: target, zoom: 16),
            markers: {
              Marker(markerId: const MarkerId('loc'), position: target),
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: SafeArea(
              top: false,
              child: AppButton(
                label: 'Open in Google Maps',
                icon: Icons.open_in_new,
                onPressed: () => launchUrl(
                  Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
