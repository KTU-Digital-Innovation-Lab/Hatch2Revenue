// One-off: turns the rooster art into a flat, tintable silhouette glyph
// so it can be used as a nav icon (via ImageIcon, which recolours by the
// image's alpha). Material has no chicken icon, so this is our stand-in.
//
// Output: assets/hen_glyph.png (transparent bg, opaque hen shape)
// Run: dart run tool/make_hen_glyph.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/chicken.png').readAsBytesSync())!;

  // Flatten to a silhouette: keep each pixel's alpha, drop the colour.
  final sil = img.Image(width: src.width, height: src.height, numChannels: 4);
  int minX = src.width, minY = src.height, maxX = 0, maxY = 0;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final a = src.getPixel(x, y).a.toInt();
      sil.setPixelRgba(x, y, 0, 0, 0, a);
      if (a > 25) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  // Crop to the hen, then centre on a square canvas with a small margin
  // so the glyph reads well at small sizes.
  final cw = maxX - minX + 1;
  final ch = maxY - minY + 1;
  final cropped = img.copyCrop(sil, x: minX, y: minY, width: cw, height: ch);
  final side = ((cw > ch ? cw : ch) * 1.14).round();
  final canvas = img.Image(width: side, height: side, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));
  img.compositeImage(canvas, cropped,
      dstX: ((side - cw) / 2).round(), dstY: ((side - ch) / 2).round());

  File('assets/hen_glyph.png').writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln('wrote assets/hen_glyph.png ${side}x$side '
      '(hen bbox ${cw}x$ch from ${src.width}x${src.height})');
}
