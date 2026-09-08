import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// What a missing image stands in for — drives the role icon.
enum PlaceholderRole { avatar, post, video, cover }

/// A gradient-tint image placeholder with a centered role icon, from the Lyra
/// Placeholder Kit. Shown while a real image loads or when one doesn't exist —
/// post media, avatars, business media, order thumbnails. Fills its parent when
/// [size] is null; theme-aware (uses the Aurora Bloom gradient tokens).
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    this.role = PlaceholderRole.post,
    this.size,
    this.radius = 12,
    this.durationLabel,
  });

  final PlaceholderRole role;
  final double? size;
  final double radius;

  /// For [PlaceholderRole.video] — a "0:00" chip in the corner.
  final String? durationLabel;

  IconData get _icon => switch (role) {
        PlaceholderRole.avatar => Icons.person_outline,
        PlaceholderRole.video => Icons.play_circle_outline,
        PlaceholderRole.post => Icons.image_outlined,
        PlaceholderRole.cover => Icons.photo_size_select_actual_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final nex = context.nexveero;
    final circle = role == PlaceholderRole.avatar;
    final iconSize = size == null ? 34.0 : (size! * 0.4).clamp(16.0, 40.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            nex.gradientStart.withValues(alpha: 0.14),
            nex.gradientEnd.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              padding: EdgeInsets.all(iconSize * 0.32),
              decoration: BoxDecoration(
                color: nex.gradientStart.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon,
                  size: iconSize,
                  color: nex.gradientStart.withValues(alpha: 0.85)),
            ),
          ),
          if (role == PlaceholderRole.video && durationLabel != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(durationLabel!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
