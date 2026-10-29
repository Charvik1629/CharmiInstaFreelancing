import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'full_image_view.dart';

/// Circular avatar. Shows the network image when [imageUrl] is set, otherwise a
/// gradient monogram from [name]'s initials. Optional story-ring border.
///
/// With [enlargeOnTap], tapping an avatar that has a photo opens it full-screen
/// with pinch-to-zoom (a DP can be viewed large).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    this.ring = false,
    this.enlargeOnTap = false,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final bool ring;
  final bool enlargeOnTap;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final nexveero = context.nexveero;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage ? null : nexveero.primaryGradient,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (context, _, _) => _monogram(context),
            )
          : _monogram(context),
    );

    if (ring) {
      avatar = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: nexveero.primaryGradient,
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          child: avatar,
        ),
      );
    }

    if (enlargeOnTap && hasImage) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => FullImageView(url: imageUrl!),
        )),
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _monogram(BuildContext context) => Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      );
}
