// One-off: renders sample cedi amounts with the embedded Inter fonts —
// the same setup PdfReportService now uses — so the fix can be verified
// visually before shipping. Output: build/cedi_test.pdf
// Run: dart run tool/make_cedi_test_pdf.dart
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  pw.Font ttf(String p) =>
      pw.Font.ttf(File(p).readAsBytesSync().buffer.asByteData());
  final theme = pw.ThemeData.withFont(
    base: ttf('google_fonts/Inter-Regular.ttf'),
    bold: ttf('google_fonts/Inter-Bold.ttf'),
  );

  final pdf = pw.Document();
  pdf.addPage(pw.Page(
    theme: theme,
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Financial Summary',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Total Income: ₵12,345.00', style: const pw.TextStyle(fontSize: 14)),
        pw.Text('Total Expenses: ₵8,760.50', style: const pw.TextStyle(fontSize: 14)),
        pw.Text('Net Profit / (Loss): ₵3,584.50',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  ));
  File('build/cedi_test.pdf').writeAsBytesSync(await pdf.save());
  stdout.writeln('wrote build/cedi_test.pdf');
}
