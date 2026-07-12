// One-off: builds launcher icons that mirror the splash screen — the
// rooster in a light circular badge on the agricultural green gradient.
//
// Outputs (all clean RGBA PNGs so flutter_launcher_icons is happy):
//   assets/splash_icon.png  1024² master (iOS / Windows / Web / Android legacy)
//   assets/splash_bg.png    1024² gradient only (Android adaptive background)
//   assets/splash_fg.png    1024² badge + rooster, transparent (adaptive foreground)
//
// Run: dart run tool/make_splash_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

const int size = 1024;

// Agricultural green gradient — the splash palette deepened toward the
// FarmNest primary so it reads as a branded icon, not a pale square.
final _g0 = img.ColorRgb8(0xEA, 0xF3, 0xE7); // soft green-white (top-left)
final _g1 = img.ColorRgb8(0xA5, 0xD6, 0xA7); // FarmNest light green (mid)
final _g2 = img.ColorRgb8(0x2E, 0x7D, 0x32); // FarmNest primary   (bottom-right)

final _badge = img.ColorRgb8(0xF6, 0xFB, 0xF4); // near-white surface (splash badge)
final _ring  = img.ColorRgb8(0x2E, 0x7D, 0x32); // green accent ring (splash "amber")

int _lerp(int a, int b, double t) => (a + (b - a) * t).round();

img.ColorRgb8 _grad(double t) {
  if (t < 0.5) {
    final u = t / 0.5;
    return img.ColorRgb8(
      _lerp(_g0.r.toInt(), _g1.r.toInt(), u),
      _lerp(_g0.g.toInt(), _g1.g.toInt(), u),
      _lerp(_g0.b.toInt(), _g1.b.toInt(), u),
    );
  }
  final u = (t - 0.5) / 0.5;
  return img.ColorRgb8(
    _lerp(_g1.r.toInt(), _g2.r.toInt(), u),
    _lerp(_g1.g.toInt(), _g2.g.toInt(), u),
    _lerp(_g1.b.toInt(), _g2.b.toInt(), u),
  );
}

/// Diagonal top-left → bottom-right gradient fill.
void _fillGradient(img.Image canvas) {
  final denom = (size + size - 2).toDouble();
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      canvas.setPixel(x, y, _grad((x + y) / denom));
    }
  }
}

/// Rooster resized to fit inside a circle of the given radius, centered
/// on (cx, cy) and composited onto [canvas].
void _placeRooster(img.Image canvas, img.Image rooster, int cx, int cy, int radius) {
  final target = (radius * 1.62).round(); // fits within the badge
  final scale = target / (rooster.width > rooster.height ? rooster.width : rooster.height);
  final rw = (rooster.width * scale).round();
  final rh = (rooster.height * scale).round();
  final resized = img.copyResize(rooster, width: rw, height: rh,
      interpolation: img.Interpolation.cubic);
  img.compositeImage(canvas, resized, dstX: cx - rw ~/ 2, dstY: cy - rh ~/ 2);
}

void main() {
  final rooster = img.decodePng(File('assets/chicken.png').readAsBytesSync())!;
  const cx = size ~/ 2, cy = size ~/ 2;

  // --- Master icon: gradient + badge + rooster --------------------
  final master = img.Image(width: size, height: size, numChannels: 4);
  _fillGradient(master);
  const rBadge = 356;
  img.fillCircle(master, x: cx, y: cy, radius: rBadge + 10, color: _ring);   // thin ring
  img.fillCircle(master, x: cx, y: cy, radius: rBadge, color: _badge);       // badge
  _placeRooster(master, rooster, cx, cy, rBadge);
  File('assets/splash_icon.png').writeAsBytesSync(img.encodePng(master));

  // --- Adaptive background: gradient only -------------------------
  final bg = img.Image(width: size, height: size, numChannels: 4);
  _fillGradient(bg);
  File('assets/splash_bg.png').writeAsBytesSync(img.encodePng(bg));

  // --- Adaptive foreground: badge + rooster on transparent --------
  // Kept inside the center ~62% so Android's shape mask never clips it.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  const rFg = 300;
  img.fillCircle(fg, x: cx, y: cy, radius: rFg + 9, color: _ring);
  img.fillCircle(fg, x: cx, y: cy, radius: rFg, color: _badge);
  _placeRooster(fg, rooster, cx, cy, rFg);
  File('assets/splash_fg.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('wrote assets/splash_icon.png, splash_bg.png, splash_fg.png '
      '(${size}x$size, rooster ${rooster.width}x${rooster.height})');
}
