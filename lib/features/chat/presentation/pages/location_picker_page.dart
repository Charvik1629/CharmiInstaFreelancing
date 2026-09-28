import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/maps_config.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
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

  // Places autocomplete search.
  final _search = TextEditingController();
  final _dio = Dio();
  Timer? _debounce;
  List<({String description, String placeId})> _predictions = const [];
  String? _pickedLabel;

  @override
  void initState() {
    super.initState();
    _goToCurrent(initial: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _predictions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _autocomplete(q));
  }

  Future<void> _autocomplete(String q) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        queryParameters: {'input': q, 'key': MapsConfig.apiKey},
      );
      final list = (res.data?['predictions'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _predictions = [
          for (final p in list)
            if (p is Map)
              (
                description: '${p['description']}',
                placeId: '${p['place_id']}',
              ),
        ];
      });
    } catch (_) {
      /* ignore — search just shows nothing */
    }
  }

  Future<void> _selectPlace(({String description, String placeId}) p) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _predictions = const [];
      _search.text = p.description;
      _pickedLabel = p.description;
    });
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/details/json',
        queryParameters: {
          'place_id': p.placeId,
          'fields': 'geometry',
          'key': MapsConfig.apiKey,
        },
      );
      final loc = res.data?['result']?['geometry']?['location'];
      if (loc == null || !mounted) return;
      final target = LatLng((loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble());
      setState(() => _center = target);
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    } catch (_) {
      /* ignore */
    }
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
                onPressed: () => Navigator.of(context).pop(PickedLocation(
                    _center.latitude, _center.longitude,
                    label: _pickedLabel)),
              ),
            ),
          ),
          // Search a place (Google Places autocomplete) at the top.
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.sm,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: TextField(
                      controller: _search,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search a place…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _predictions = const []);
                                },
                              ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (_predictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 12),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _predictions.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: context.nexveero.border),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined, size: 20),
                          title: Text(_predictions[i].description,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _selectPlace(_predictions[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
