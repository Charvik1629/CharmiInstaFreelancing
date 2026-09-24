import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Picked location returned by [LocationPickerPage].
class PickedLocation {
  const PickedLocation(this.lat, this.lng, {this.label});
  final double lat;
  final double lng;
  final String? label;
}

/// WhatsApp-style "share location" picker: a map with a fixed centre pin — pan
/// the map to place it, then Send. Recenters on the user's current location.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _fallback = LatLng(19.076, 72.8777); // Mumbai
  GoogleMapController? _controller;
  LatLng _center = _fallback;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _goToCurrent(initial: true);
  }

  Future<Position?> _current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _goToCurrent({bool initial = false}) async {
    final pos = await _current();
    if (!mounted) return;
    if (pos != null) {
      final target = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = target;
        _ready = true;
      });
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    } else if (initial) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send location')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            initialCameraPosition:
                CameraPosition(target: _center, zoom: _ready ? 16 : 12),
            onMapCreated: (c) => _controller = c,
            onCameraMove: (pos) => _center = pos.target,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          // Fixed centre pin (sits slightly above centre so the tip marks the spot).
          const Padding(
            padding: EdgeInsets.only(bottom: 36),
            child: Icon(Icons.location_on, size: 44, color: Color(0xFFEA4335)),
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'myloc',
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.primary,
              onPressed: () => _goToCurrent(),
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: SafeArea(
              top: false,
              child: AppButton(
                label: 'Send this location',
                icon: Icons.send,
                onPressed: () => Navigator.of(context)
                    .pop(PickedLocation(_center.latitude, _center.longitude)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
