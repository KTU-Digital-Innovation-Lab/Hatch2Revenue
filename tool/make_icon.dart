// One-off: pads the rooster logo onto a square transparent canvas so
// flutter_launcher_icons (which needs a square source) can generate
// crisp launcher icons. Output: assets/chicken_icon.png
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/chicken.png').readAsBytesSync())!;
  // Square canvas 12% larger than the longest side, centered, transparent.
  final side = (src.width > src.height ? src.width : src.height);
  final canvasSize = (side * 1.12).round();
  final canvas = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  // Fully transparent background.
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  final dx = ((canvasSize - src.width) / 2).round();
  final dy = ((canvasSize - src.height) / 2).round();
  img.compositeImage(canvas, src, dstX: dx, dstY: dy);
  File('assets/chicken_icon.png').writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('wrote assets/chicken_icon.png ${canvasSize}x$canvasSize '
      '(source ${src.width}x${src.height})');
}
