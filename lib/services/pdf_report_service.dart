import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/financial_transaction.dart';
import '../utils/currency_formatter.dart';
import '../utils/units.dart';

class PdfReportService {
  /// Builds the farm report. With [share] true the platform share sheet
  /// opens (WhatsApp, email, ...); otherwise the print/preview dialog.
  static Future<void> generateFarmReport({
    required BuildContext context,
    required String farmName,
    required String ownerName,
    required int totalBirds,
    required int totalBatches,
    required int totalEggs,
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
    required List<FinancialTransaction> transactions,
    bool share = false,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('d MMMM yyyy').format(DateTime.now());

    // Embed the bundled Inter font: the PDF default (Helvetica) has no
    // Ghana cedi glyph (₵ U+20B5), so amounts printed as garbage. Inter
    // carries the glyph (Poppins doesn't) and matches the app's body font.
    final interRegular =
        pw.Font.ttf(await rootBundle.load('google_fonts/Inter-Regular.ttf'));
    final interBold =
        pw.Font.ttf(await rootBundle.load('google_fonts/Inter-Bold.ttf'));
    final theme = pw.ThemeData.withFont(
      base: interRegular,
      bold: interBold,
      italic: interRegular,
      boldItalic: interBold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Hatch2Revenue Farm Report',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(date, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            if (farmName.isNotEmpty)
              pw.Text(farmName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            if (ownerName.isNotEmpty)
              pw.Text('Owner: $ownerName', style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (ctx) => [
          pw.Text('Farm Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Metric', 'Value'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            data: [
              ['Total Birds', '$totalBirds'],
              ['Active Batches', '$totalBatches'],
              ['Total Crates Produced', '${Units.crateShort(totalEggs)} (${Units.crateLabel(totalEggs)})'],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Financial Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Item', 'Amount'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            data: [
              ['Total Income', '${CurrencyFormatter.currencySymbol}${totalRevenue.toStringAsFixed(2)}'],
              ['Total Expenses', '${CurrencyFormatter.currencySymbol}${totalExpenses.toStringAsFixed(2)}'],
              ['Net Profit / (Loss)', '${CurrencyFormatter.currencySymbol}${netProfit.toStringAsFixed(2)}'],
            ],
          ),
          pw.SizedBox(height: 16),
          if (transactions.isNotEmpty) ...[
            pw.Text('Transaction History', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Date', 'Type', 'Category', 'Amount', 'Description'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              data: transactions.map((t) => [
                DateFormat('d/M/yy').format(t.date),
                t.type == TransactionType.income ? 'Income' : 'Expense',
                t.categoryName,
                '${t.type == TransactionType.income ? '+' : '-'}${CurrencyFormatter.currencySymbol}${t.amount.toStringAsFixed(2)}',
                t.description ?? '',
              ]).toList(),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'Generated by Hatch2Revenue • $date',
              style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
            ),
          ),
        ],
      ),
    );

    final filename =
        'FarmReport_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    if (share) {
      await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: filename,
      );
    }
  }

  // Legacy stub kept for compatibility
  static Future<void> generateFinancialReport({
    required List<dynamic> transactions,
    required double totalIncome,
    required double totalExpenses,
    required double netProfit,
  }) async {
    debugPrint('Use generateFarmReport() instead');
  }

  static Future<void> generateSummaryReport({
    required int totalBirds,
    required int totalBatches,
    required int totalCrates,
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
  }) async {
    debugPrint('Use generateFarmReport() instead');
  }
}
