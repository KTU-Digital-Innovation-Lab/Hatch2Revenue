// One-off: does each bundled TTF contain the Ghana cedi sign (U+20B5)?
// The PDF report can only show ₵ if the embedded font has the glyph.
// Run: dart run tool/check_cedi_glyph.dart
import 'dart:io';
import 'package:pdf/pdf.dart';

void main() {
  const cedi = 0x20B5;
  for (final path in [
    'google_fonts/Inter-Regular.ttf',
    'google_fonts/Inter-Bold.ttf',
    'google_fonts/Poppins-Regular.ttf',
    'google_fonts/Poppins-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    final font = TtfParser(bytes.buffer.asByteData());
    final glyph = font.charToGlyphIndexMap[cedi];
    stdout.writeln(
        '$path: ₵ ${glyph != null && glyph != 0 ? "PRESENT (glyph $glyph)" : "MISSING"}');
  }
}
