import 'package:flutter/material.dart';

/// The CheckMate mark — the launcher icon itself, so the logo inside the app
/// is the one people tap on their home screen. (It used to be a "♞" font
/// glyph on a gold square, which depended on the phone's fonts.)
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'CheckMate',
      image: true,
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        // The file is 1024 px; decode it at the size shown.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
