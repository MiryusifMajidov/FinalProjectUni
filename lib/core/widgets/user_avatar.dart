import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Universal avatar widget used across the entire app.
///
/// Priority: photoUrl (real photo) → initial letter (username[0])
/// Shape: circle when [rounded] is false, squircle when true.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String username;
  final double size;

  /// If true, uses a squircle (rounded rect) instead of a circle.
  /// Use for large profile display (profile screen header).
  final bool squircle;

  const UserAvatar({
    super.key,
    required this.username,
    this.photoUrl,
    this.size = 40,
    this.squircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = squircle
        ? BorderRadius.circular(size * 0.28)
        : BorderRadius.circular(size / 2);

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Fallback(
              size: size, username: username, radius: radius),
          errorWidget: (_, __, ___) => _Fallback(
              size: size, username: username, radius: radius),
        ),
      );
    }

    return _Fallback(size: size, username: username, radius: radius);
  }
}

class _Fallback extends StatelessWidget {
  final double size;
  final String username;
  final BorderRadius radius;

  const _Fallback({
    required this.size,
    required this.username,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        username.isNotEmpty ? username[0].toUpperCase() : '?';
    final fontSize = (size * 0.38).clamp(10.0, 36.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          initial,
          style: AppTextStyles.titleLarge.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
