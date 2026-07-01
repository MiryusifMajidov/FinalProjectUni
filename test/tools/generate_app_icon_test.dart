// App icon generator — renders the multi-game launcher icon (chess knight +
// checkers disc + domino tile on the dark brand background) to PNG using the
// real Flutter engine, so the output matches in-app rendering exactly.
//
// Run with:  flutter test test/tools/generate_app_icon_test.dart
//
// Outputs:
//   assets/images/app_icon.png             (1024×1024, full icon)
//   assets/images/app_icon_foreground.png  (1024×1024, adaptive foreground)

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

// The trio artwork shared by both outputs. Knight paths come from the app's
// own cburnett piece set (assets/pieces/cburnett/wN.svg) tinted brand gold.
const _trio = '''
    <!-- Accent glows -->
    <circle cx="360" cy="470" r="380" fill="url(#glowAmber)"/>
    <circle cx="780" cy="320" r="270" fill="url(#glowGreen)"/>
    <circle cx="735" cy="800" r="240" fill="url(#glowBlue)"/>

    <!-- Chess knight (gold) -->
    <g transform="translate(10,140) scale(16)"
       stroke="#6B5226" stroke-width="1.1"
       stroke-linecap="round" stroke-linejoin="round" fill-rule="evenodd">
      <path fill="url(#gold)" d="M22 10c10.5 1 16.5 8 16 29H15c0-9 10-6.5 8-21"/>
      <path fill="url(#gold)" d="M24 18c.38 2.91-5.55 7.37-8 9-3 2-2.82 4.34-5 4-1.042-.94 1.41-3.04 0-3-1 0 .19 1.23-1 2-1 0-4.003 1-4-4 0-2 6-12 6-12s1.89-1.9 2-3.5c-.73-.994-.5-2-.5-3 1-1 3 2.5 3 2.5h2s.78-1.992 2.5-3c1 0 1 3 1 3"/>
      <path fill="#5A431D" stroke="none" d="M9.5 25.5a.5.5 0 1 1-1 0 .5.5 0 1 1 1 0m5.433-9.75a.5 1.5 30 1 1-.866-.5.5 1.5 30 1 1 .866.5"/>
    </g>

    <!-- Domino tile (double-six, emerald accent) -->
    <g transform="rotate(12 770 335)">
      <rect x="670" y="130" width="200" height="410" rx="26"
            fill="url(#bone)" stroke="#57B98F" stroke-width="6"/>
      <line x1="700" y1="335" x2="840" y2="335"
            stroke="#C9BC9C" stroke-width="5" stroke-linecap="round"/>
      <!-- top half: 6 pips -->
      <circle cx="725" cy="180" r="17" fill="#221C12"/>
      <circle cx="725" cy="244" r="17" fill="#221C12"/>
      <circle cx="725" cy="308" r="17" fill="#221C12"/>
      <circle cx="815" cy="180" r="17" fill="#221C12"/>
      <circle cx="815" cy="244" r="17" fill="#221C12"/>
      <circle cx="815" cy="308" r="17" fill="#221C12"/>
      <!-- bottom half: 6 pips -->
      <circle cx="725" cy="364" r="17" fill="#221C12"/>
      <circle cx="725" cy="428" r="17" fill="#221C12"/>
      <circle cx="725" cy="492" r="17" fill="#221C12"/>
      <circle cx="815" cy="364" r="17" fill="#221C12"/>
      <circle cx="815" cy="428" r="17" fill="#221C12"/>
      <circle cx="815" cy="492" r="17" fill="#221C12"/>
    </g>

    <!-- Checkers disc (ice blue) -->
    <ellipse cx="735" cy="812" rx="132" ry="120" fill="#2E5972"/>
    <circle cx="735" cy="788" r="128" fill="url(#blueDisc)" stroke="#2E5E80" stroke-width="5"/>
    <circle cx="735" cy="788" r="88" fill="none" stroke="#EAF4FB" stroke-opacity="0.65" stroke-width="7"/>
    <circle cx="735" cy="788" r="48" fill="none" stroke="#EAF4FB" stroke-opacity="0.5" stroke-width="5"/>
''';

const _defs = '''
  <defs>
    <radialGradient id="bgGlow" cx="50%" cy="40%" r="78%">
      <stop offset="0%" stop-color="#1E1E25"/>
      <stop offset="100%" stop-color="#0A0A0B"/>
    </radialGradient>
    <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#F2CD86"/>
      <stop offset="55%" stop-color="#E8B960"/>
      <stop offset="100%" stop-color="#C3924A"/>
    </linearGradient>
    <linearGradient id="bone" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FAF5E6"/>
      <stop offset="100%" stop-color="#E2D7BC"/>
    </linearGradient>
    <linearGradient id="blueDisc" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#8CC4EA"/>
      <stop offset="100%" stop-color="#4A86B4"/>
    </linearGradient>
    <radialGradient id="glowAmber" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#E8B960" stop-opacity="0.20"/>
      <stop offset="100%" stop-color="#E8B960" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowGreen" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#5FD4A3" stop-opacity="0.18"/>
      <stop offset="100%" stop-color="#5FD4A3" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowBlue" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#6FB4E0" stop-opacity="0.20"/>
      <stop offset="100%" stop-color="#6FB4E0" stop-opacity="0"/>
    </radialGradient>
  </defs>
''';

/// Full icon: dark rounded-square card + trio.
const _fullIconSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
$_defs
  <rect x="0" y="0" width="1024" height="1024" rx="226" fill="url(#bgGlow)"/>
  <rect x="6" y="6" width="1012" height="1012" rx="222" fill="none"
        stroke="#2A2A32" stroke-width="4"/>
$_trio
</svg>
''';

/// Adaptive foreground: transparent background, trio scaled into the
/// central safe zone (~66%) so launcher masks never clip it.
const _foregroundSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
$_defs
  <g transform="translate(154,154) scale(0.70)">
$_trio
  </g>
</svg>
''';

/// Google Play Store listing icon: 512×512, fully opaque, full-bleed square
/// (Play applies its own rounded-corner mask — no transparency allowed).
const _storeIconSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
$_defs
  <rect x="0" y="0" width="1024" height="1024" fill="url(#bgGlow)"/>
  <g transform="translate(102,102) scale(0.80)">
$_trio
  </g>
</svg>
''';

/// Google Play feature graphic: 1024×500, opaque. Pure artwork (no text —
/// Play overlays the app name/icon on top of it in promo placements).
const _featureGraphicSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 500">
$_defs
  <rect x="0" y="0" width="1024" height="500" fill="url(#bgGlow)"/>
  <g transform="translate(262,5) scale(0.48)">
$_trio
  </g>
</svg>
''';

Future<void> _renderSvgToPng(String svg, String outPath, int width,
    [int? height]) async {
  final h = height ?? width;
  final pictureInfo = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(width / pictureInfo.size.width, h / pictureInfo.size.height);
  canvas.drawPicture(pictureInfo.picture);
  final image = await recorder.endRecording().toImage(width, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(outPath).writeAsBytesSync(bytes!.buffer.asUint8List());
  pictureInfo.picture.dispose();
  image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate launcher icons', () async {
    await _renderSvgToPng(_fullIconSvg, 'assets/images/app_icon.png', 1024);
    await _renderSvgToPng(
        _foregroundSvg, 'assets/images/app_icon_foreground.png', 1024);
    await _renderSvgToPng(
        _storeIconSvg, 'assets/images/app_icon_store_512.png', 512);
    await _renderSvgToPng(_featureGraphicSvg,
        'assets/images/play_feature_graphic.png', 1024, 500);

    expect(File('assets/images/app_icon.png').lengthSync(), greaterThan(1000));
    expect(File('assets/images/app_icon_foreground.png').lengthSync(),
        greaterThan(1000));
    expect(File('assets/images/app_icon_store_512.png').lengthSync(),
        greaterThan(1000));
  });
}
