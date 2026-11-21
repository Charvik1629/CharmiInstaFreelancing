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
  const LocationPickerPage({
    super.key,
    this.initialLocation,
    this.title = 'Send location',
    this.confirmLabel = 'Send this location',
  });

  final PickedLocation? initialLocation;
  final String title;
  final String confirmLabel;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _fallback = LatLng(19.076, 72.8777); // Mumbai
  GoogleMapController? _controller;
  LatLng _center = _fallback;
  bool _ready = false;
  bool _permissionGranted = false;
  bool _selecting = false;
  int _searchVersion = 0;
  int _selectionVersion = 0;

  // Places autocomplete search.
  final _search = TextEditingController();
  final _dio = Dio();
  Timer? _debounce;
  List<({String description, String placeId})> _predictions = const [];
  String? _pickedLabel;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLocation;
    if (initial != null) {
      _center = LatLng(initial.lat, initial.lng);
      _pickedLabel = initial.label;
      _search.text = initial.label ?? '';
      _ready = true;
      _ensurePermission();
    } else {
      _goToCurrent(initial: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _dio.close(force: true);
    _controller?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    ++_searchVersion;
    setState(() {
      _predictions = const [];
      _selecting = false;
    });
    if (q.trim().length < 3) {
      setState(() => _predictions = const []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _autocomplete(q),
    );
  }

  Future<void> _autocomplete(String q) async {
    final version = _searchVersion;
    try {
      // Places API (New): POST places:autocomplete with the key in a header.
      final res = await _dio.post(
        'https://places.googleapis.com/v1/places:autocomplete',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': MapsConfig.apiKey,
          },
        ),
        data: {'input': q},
      );
      final list = (res.data?['suggestions'] as List?) ?? const [];
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _predictions = [
          for (final s in list)
            if (s is Map && s['placePrediction'] is Map)
              (
                description:
                    '${(s['placePrediction']['text'] as Map?)?['text'] ?? ''}',
                placeId: '${s['placePrediction']['placeId'] ?? ''}',
              ),
        ];
      });
    } catch (_) {
      if (mounted && version == _searchVersion) {
        AppOverlays.snack(
          context,
          'Place search is unavailable. You can choose a point on the map.',
        );
      }
    }
  }

  Future<void> _selectPlace(({String description, String placeId}) p) async {
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    final version = ++_searchVersion;
    final selectionVersion = ++_selectionVersion;
    setState(() {
      _selecting = true;
      _predictions = const [];
      _search.text = p.description;
    });
    try {
      // Places API (New): GET places/{id} with a `location` field mask.
      final res = await _dio.get(
        'https://places.googleapis.com/v1/places/${p.placeId}',
        options: Options(
          headers: {
            'X-Goog-Api-Key': MapsConfig.apiKey,
            'X-Goog-FieldMask': 'location',
          },
        ),
      );
      final loc = res.data?['location'];
      if (!mounted ||
          version != _searchVersion ||
          selectionVersion != _selectionVersion) {
        return;
      }
      if (loc == null) throw StateError('Missing place location');
      final target = LatLng(
        (loc['latitude'] as num).toDouble(),
        (loc['longitude'] as num).toDouble(),
      );
      setState(() {
        _center = target;
        _pickedLabel = p.description;
      });
      _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    } catch (_) {
      if (mounted && version == _searchVersion) {
        AppOverlays.snack(
          context,
          'Could not load that place. Please try again.',
        );
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _selecting = false);
      }
    }
  }

  /// Ensures location permission, prompting the OS dialog when undecided.
  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    final granted =
        perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
    if (mounted) setState(() => _permissionGranted = granted);
    return granted;
  }

  Future<Position?> _current() async {
    try {
      // Ask permission first (so the app prompts on open), then the live fix.
      if (!await _ensurePermission()) return null;
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          AppOverlays.snack(
            context,
            'Turn on location to use your current spot.',
          );
        }
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _lastKnown() async {
    try {
      if (!await _ensurePermission()) return null;
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  void _moveTo(Position pos) {
    final target = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _center = target;
      _ready = true;
    });
    _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  Future<void> _goToCurrent({bool initial = false}) async {
    final version = initial ? _selectionVersion : ++_selectionVersion;
    if (!initial) {
      ++_searchVersion;
      _debounce?.cancel();
      _search.clear();
      setState(() {
        _pickedLabel = null;
        _predictions = const [];
      });
    }
    // On open, center instantly on the last cached fix, then refine with a
    // fresh one, so the pin starts on (or near) the user's current place.
    if (initial) {
      final last = await _lastKnown();
      if (last != null && mounted && version == _selectionVersion) {
        _moveTo(last);
      }
    }
    final pos = await _current();
    if (!mounted || version != _selectionVersion) return;
    if (pos != null) {
      _moveTo(pos);
    } else if (initial) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Listener(
            onPointerDown: (_) {
              ++_selectionVersion;
              _pickedLabel = null;
            },
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: _ready ? 16 : 12,
              ),
              onMapCreated: (c) {
                _controller = c;
                if (_ready) {
                  c.moveCamera(CameraUpdate.newLatLngZoom(_center, 16));
                }
              },
              onCameraMove: (pos) => _center = pos.target,
              myLocationEnabled: _permissionGranted,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
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
                label: widget.confirmLabel,
                icon: Icons.send,
                onPressed: _selecting
                    ? null
                    : () => Navigator.of(context).pop(
                        PickedLocation(
                          _center.latitude,
                          _center.longitude,
                          label: _pickedLabel,
                        ),
                      ),
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
                                  _onSearchChanged('');
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
                            blurRadius: 12,
                          ),
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
                          leading: const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                          ),
                          title: Text(
                            _predictions[i].description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
