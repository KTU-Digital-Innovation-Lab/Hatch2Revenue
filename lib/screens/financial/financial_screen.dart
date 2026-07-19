import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/financial_transaction.dart';
import '../../providers/financial_provider.dart';
import '../../providers/farm_profile_provider.dart';
import '../../providers/batch_provider.dart';
import '../../providers/egg_production_provider.dart';
import '../../providers/quick_action_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_colors.dart';
import '../../utils/html_widgets.dart';
import '../../services/pdf_report_service.dart';

class FinancialScreen extends StatelessWidget {
  const FinancialScreen({super.key});

  static const List<Color> _expColors = [AppColors.amber, AppColors.red, AppColors.purple, AppColors.blue, AppColors.cyan];
  static const List<Color> _revColors = [AppColors.green, AppColors.cyan, AppColors.purple, AppColors.blue];

  @override
  Widget build(BuildContext context) {
    return Consumer2<FinancialProvider, QuickActionProvider>(
      builder: (context, finProvider, quickAction, _) {
        if (quickAction.action == 'addExpense') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            quickAction.clear();
            _showAddDialog(context, finProvider);
          });
        }

        final txns = finProvider.transactions;
        final rev  = finProvider.totalIncome;
        final exp  = finProvider.totalExpenses;
        final net  = finProvider.netProfit;

        final expMap = <String, double>{};
        final revMap = <String, double>{};
        for (final t in txns) {
          if (t.type == TransactionType.expense) {
            expMap[t.categoryName] = (expMap[t.categoryName] ?? 0) + t.amount;
          } else {
            revMap[t.categoryName] = (revMap[t.categoryName] ?? 0) + t.amount;
          }
        }
        final sortedExp = expMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final sortedRev = revMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Financial Dashboard',
                subtitle: 'Track expenses vs. revenue — feed, meds, labor, eggs, culled birds',
                action: Row(mainAxisSize: MainAxisSize.min, children: [
                  GhostBtn(
                    label: 'Export PDF',
                    onPressed: () => _showPdfOptions(context, rev, exp, net, txns),
                  ),
                  const SizedBox(width: 8),
                  PrimaryBtn(label: '+ Add Transaction', onPressed: () => _showAddDialog(context, finProvider)),
                ]),
              ),

              KpiGrid(children: [
                KpiCard(label: 'Total Revenue', value: '${CurrencyFormatter.currencySymbol}${rev.toStringAsFixed(0)}', accentColor: AppColors.green),
                KpiCard(label: 'Total Expenses', value: '${CurrencyFormatter.currencySymbol}${exp.toStringAsFixed(0)}', accentColor: AppColors.red),
                KpiCard(
                  label: 'Net Profit',
                  value: '${CurrencyFormatter.currencySymbol}${net.abs().toStringAsFixed(0)}',
                  accentColor: net >= 0 ? AppColors.green : AppColors.red,
                ),
                KpiCard(label: 'Transactions', value: '${txns.length}', accentColor: AppColors.cyan),
              ]),
              const SizedBox(height: 18),

              _twoCol(
                left: HtmlCard(
                  header: const HtmlCardHeader(icon: Icons.trending_down, title: 'Expense Breakdown'),
                  body: sortedExp.isEmpty
                      ? const HtmlEmptyState(icon: Icons.trending_down, message: 'No expenses logged yet.')
                      : Column(
                          children: sortedExp.asMap().entries.map((e) {
                            final pct = exp > 0 ? (e.value.value / exp * 100).round() : 0;
                            return CauseBarRow(
                              label: e.value.key,
                              percent: pct,
                              color: _expColors[e.key % _expColors.length],
                              valueLabel: '${CurrencyFormatter.currencySymbol}${e.value.value.toStringAsFixed(0)}',
                            );
                          }).toList(),
                        ),
                ),
                right: HtmlCard(
                  header: const HtmlCardHeader(icon: Icons.trending_up, title: 'Revenue Breakdown'),
                  body: sortedRev.isEmpty
                      ? const HtmlEmptyState(icon: Icons.trending_up, message: 'No revenue logged yet.')
                      : Column(
                          children: sortedRev.asMap().entries.map((e) {
                            final pct = rev > 0 ? (e.value.value / rev * 100).round() : 0;
                            return CauseBarRow(
                              label: e.value.key,
                              percent: pct,
                              color: _revColors[e.key % _revColors.length],
                              valueLabel: '${CurrencyFormatter.currencySymbol}${e.value.value.toStringAsFixed(0)}',
                            );
                          }).toList(),
                        ),
                ),
              ),

              HtmlCard(
                header: const HtmlCardHeader(icon: Icons.list_alt_outlined, title: 'All Transactions'),
                bodyPadding: EdgeInsets.zero,
                body: txns.isEmpty
                    ? HtmlEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        message: 'No transactions yet.',
                        action: PrimaryBtn(label: '+ Add Transaction', small: true, onPressed: () => _showAddDialog(context, finProvider)),
                      )
                    : _txnTable(context, txns, finProvider),
              ),

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }

  void _showPdfOptions(BuildContext context, double rev, double exp, double net, List<FinancialTransaction> txns) {
    Future<void> generate(bool share) {
      final fp    = context.read<FarmProfileProvider>();
      final batch = context.read<BatchProvider>();
      final eggs  = context.read<EggProductionProvider>();
      return PdfReportService.generateFarmReport(
        context: context,
        farmName: fp.profile.farmName,
        ownerName: fp.profile.ownerName,
        totalBirds: batch.totalBirds,
        totalBatches: batch.batches.length,
        totalEggs: eggs.totalEggs,
        totalRevenue: rev,
        totalExpenses: exp,
        netProfit: net,
        transactions: txns,
        share: share,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Farm Report'),
        content: Text(
          'How do you want the PDF report?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.print_outlined, size: 18, color: AppColors.textSecondary),
            label: Text('Print / Preview', style: TextStyle(color: AppColors.textSecondary)),
            onPressed: () {
              Navigator.pop(ctx);
              generate(false);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_outlined, size: 16),
            label: const Text('Share'),
            onPressed: () {
              Navigator.pop(ctx);
              generate(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _twoCol({required Widget left, required Widget right}) {
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth < 500) return Column(children: [left, right]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: left), const SizedBox(width: 14), Expanded(child: right),
      ]);
    });
  }

  Widget _txnTable(BuildContext context, List<FinancialTransaction> txns, FinancialProvider provider) {
    final sorted = [...txns]..sort((a, b) => b.date.compareTo(a.date));
    return HtmlTable(
      headers: ['Date', 'Type', 'Category', 'Amount', 'Desc', ''],
      rows: sorted.map((t) {
        final isIncome = t.type == TransactionType.income;
        return [
          Text(DateFormat('d MMM yyyy').format(t.date), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
          TagChip(label: isIncome ? 'revenue' : 'expense', color: isIncome ? AppColors.green : AppColors.red),
          Text(t.categoryName, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 11)),
          Text(
            '${isIncome ? '+' : '-'}${CurrencyFormatter.currencySymbol}${t.amount.toStringAsFixed(0)}',
            style: GoogleFonts.inter(color: isIncome ? AppColors.green : AppColors.red, fontWeight: FontWeight.w500, fontSize: 12),
          ),
          Text(t.description ?? '—', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            EditBtn(onTap: () => _showEditDialog(context, t, provider)),
            DelBtn(onTap: () => _confirmDelete(context, t, provider)),
          ]),
        ];
      }).toList(),
    );
  }

  void _showAddDialog(BuildContext context, FinancialProvider provider) {
    int selectedType     = 1;
    int selectedCategory = 0;
    final amountCtrl = TextEditingController();
    final descCtrl   = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Add Transaction'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: 'Date',
                child: HtmlDateTile(
                  date: selectedDate,
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (d != null) ss(() => selectedDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Type',
                child: DropdownButtonFormField<int>(
                  initialValue: selectedType,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: [
                    DropdownMenuItem(value: 0, child: Text('Revenue', style: TextStyle(color: AppColors.textPrimary))),
                    DropdownMenuItem(value: 1, child: Text('Expense', style: TextStyle(color: AppColors.textPrimary))),
                  ],
                  onChanged: (v) => ss(() => selectedType = v ?? 1),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Category',
                child: DropdownButtonFormField<int>(
                  initialValue: selectedCategory,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: TransactionCategory.values.map((c) => DropdownMenuItem(
                    value: c.index,
                    child: Text(c.name[0].toUpperCase() + c.name.substring(1), style: TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedCategory = v ?? 0),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Amount (${CurrencyFormatter.currencySymbol})',
                child: TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('e.g. 500')),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Description',
                child: TextField(controller: descCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Short description...')),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                provider.addTransaction(FinancialTransaction(
                  date: selectedDate,
                  type: TransactionType.values[selectedType],
                  category: TransactionCategory.values[selectedCategory],
                  amount: amount,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Transaction saved'),
                  backgroundColor: AppColors.green.withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, FinancialTransaction txn, FinancialProvider provider) {
    int selectedType     = txn.type.index;
    int selectedCategory = txn.category.index;
    final amountCtrl = TextEditingController(text: '${txn.amount}');
    final descCtrl   = TextEditingController(text: txn.description ?? '');
    DateTime selectedDate = txn.date;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              HtmlFormField(
                label: 'Date',
                child: HtmlDateTile(
                  date: selectedDate,
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (d != null) ss(() => selectedDate = d);
                  },
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Type',
                child: DropdownButtonFormField<int>(
                  initialValue: selectedType,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: [
                    DropdownMenuItem(value: 0, child: Text('Revenue', style: TextStyle(color: AppColors.textPrimary))),
                    DropdownMenuItem(value: 1, child: Text('Expense', style: TextStyle(color: AppColors.textPrimary))),
                  ],
                  onChanged: (v) => ss(() => selectedType = v ?? 0),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Category',
                child: DropdownButtonFormField<int>(
                  initialValue: selectedCategory,
                  dropdownColor: AppColors.surfaceLight,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: htmlInputDec(),
                  items: TransactionCategory.values.map((c) => DropdownMenuItem(
                    value: c.index,
                    child: Text(c.name[0].toUpperCase() + c.name.substring(1), style: TextStyle(color: AppColors.textPrimary)),
                  )).toList(),
                  onChanged: (v) => ss(() => selectedCategory = v ?? 0),
                ),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Amount',
                child: TextField(controller: amountCtrl, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Amount')),
              ),
              const SizedBox(height: 12),
              HtmlFormField(
                label: 'Description',
                child: TextField(controller: descCtrl, style: TextStyle(color: AppColors.textPrimary), decoration: htmlInputDec('Description')),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                provider.updateTransaction(txn.copyWith(
                  date: selectedDate,
                  type: TransactionType.values[selectedType],
                  category: TransactionCategory.values[selectedCategory],
                  amount: amount,
                  description: descCtrl.text.trim(),
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Transaction updated'),
                  backgroundColor: AppColors.cyan,
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FinancialTransaction txn, FinancialProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('This action cannot be undone.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
            onPressed: () { provider.removeTransaction(txn.id); Navigator.pop(ctx); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
