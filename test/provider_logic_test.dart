import 'package:flutter_test/flutter_test.dart';
import 'package:hatch2revenue/models/batch.dart';
import 'package:hatch2revenue/models/egg_production.dart';
import 'package:hatch2revenue/models/feed_record.dart';
import 'package:hatch2revenue/models/financial_transaction.dart';
import 'package:hatch2revenue/models/mortality.dart';
import 'package:hatch2revenue/providers/batch_provider.dart';
import 'package:hatch2revenue/providers/egg_production_provider.dart';
import 'package:hatch2revenue/providers/feed_provider.dart';
import 'package:hatch2revenue/providers/financial_provider.dart';
import 'package:hatch2revenue/providers/mortality_provider.dart';
import 'package:hatch2revenue/providers/theme_provider.dart';
import 'package:hatch2revenue/utils/app_colors.dart';

void main() {
  group('FinancialProvider', () {
    test('income, expenses and net profit', () {
      final p = FinancialProvider();
      p.addTransaction(FinancialTransaction(
        date: DateTime.now(),
        type: TransactionType.income,
        category: TransactionCategory.eggSales,
        amount: 500,
      ));
      p.addTransaction(FinancialTransaction(
        date: DateTime.now(),
        type: TransactionType.expense,
        category: TransactionCategory.feed,
        amount: 320,
      ));
      expect(p.totalIncome, 500);
      expect(p.totalExpenses, 320);
      expect(p.netProfit, 180);
    });
  });

  group('EggProductionProvider', () {
    test('averagePerDay divides by distinct days, not record count', () {
      final p = EggProductionProvider();
      final day = DateTime(2026, 7, 1);
      // Two records on the same day + one the next day.
      p.addRecord(EggProduction(
          batchId: 'A', date: day, eggCount: 100, pricePerEgg: 0));
      p.addRecord(EggProduction(
          batchId: 'A', date: day, eggCount: 50, pricePerEgg: 0));
      p.addRecord(EggProduction(
          batchId: 'A',
          date: day.add(const Duration(days: 1)),
          eggCount: 150,
          pricePerEgg: 0));
      expect(p.totalEggs, 300);
      expect(p.averagePerDay, 150); // 300 eggs / 2 days
    });

    test('forecastNext projects a stable series', () {
      final p = EggProductionProvider();
      for (var i = 0; i < 10; i++) {
        p.addRecord(EggProduction(
          batchId: 'A',
          date: DateTime(2026, 7, 1).add(Duration(days: i)),
          eggCount: 100,
          pricePerEgg: 0,
        ));
      }
      final forecast = p.forecastNext(7);
      expect(forecast, inInclusiveRange(650, 750)); // ≈ 100/day
    });

    test('forecastNext never goes negative', () {
      final p = EggProductionProvider();
      // Steeply declining series.
      final counts = [100, 80, 60, 40, 20, 10, 5];
      for (var i = 0; i < counts.length; i++) {
        p.addRecord(EggProduction(
          batchId: 'A',
          date: DateTime(2026, 7, 1).add(Duration(days: i)),
          eggCount: counts[i],
          pricePerEgg: 0,
        ));
      }
      expect(p.forecastNext(7), greaterThanOrEqualTo(0));
    });
  });

  group('BatchProvider', () {
    test('adjustCount decrements and clamps at zero', () {
      final p = BatchProvider();
      final batch = Batch(
        name: 'B-01',
        type: BatchType.layers,
        initialCount: 100,
        currentCount: 100,
        hatchDate: DateTime(2026, 1, 1),
      );
      p.addBatch(batch);

      p.adjustCount('B-01', -10);
      expect(p.totalBirds, 90);

      // Cannot go below zero.
      p.adjustCount('B-01', -1000);
      expect(p.totalBirds, 0);

      // Restores work too.
      p.adjustCount('B-01', 5);
      expect(p.totalBirds, 5);
    });

    test('adjustCount matches by id or name and ignores unknown refs', () {
      final p = BatchProvider();
      final batch = Batch(
        name: 'B-02',
        type: BatchType.growers,
        initialCount: 50,
        currentCount: 50,
        hatchDate: DateTime(2026, 1, 1),
      );
      p.addBatch(batch);
      p.adjustCount(batch.id, -5);
      expect(p.totalBirds, 45);
      p.adjustCount('does-not-exist', -5);
      expect(p.totalBirds, 45);
    });
  });

  group('FeedProvider inventory CRUD', () {
    test('add, update, delete stock and computed getters', () {
      final p = FeedProvider();
      final item = FeedInventory(
        feedTypeName: 'Layer Mash',
        quantityKg: 500,
        unitPrice: 2.5,
        expiryDate: DateTime.now().add(const Duration(days: 90)),
      );
      p.addToInventory(item);
      expect(p.totalStockKg, 500);
      expect(p.totalStockValue, 1250);
      expect(p.stockAlertCount, 0);

      // Update: drop quantity below the low-stock threshold.
      p.updateInventory(item.copyWith(quantityKg: 20));
      expect(p.totalStockKg, 20);
      expect(p.stockAlertCount, 1); // low stock

      // Delete.
      p.removeInventory(item.id);
      expect(p.inventory, isEmpty);
      expect(p.totalStockKg, 0);
    });

    test('expired stock counts as an alert', () {
      final p = FeedProvider();
      p.addToInventory(FeedInventory(
        feedTypeName: 'Starter',
        quantityKg: 300,
        unitPrice: 3,
        expiryDate: DateTime.now().subtract(const Duration(days: 1)),
      ));
      expect(p.stockAlertCount, 1);
    });
  });

  group('ThemeProvider', () {
    test('toggle flips the palette between day and night', () {
      final p = ThemeProvider();
      // FarmNest theme is light-first: day is the default.
      AppColors.isDark = false;
      final dayBackground = AppColors.background;

      p.toggle(); // -> night
      expect(AppColors.isDark, isTrue);
      expect(AppColors.background, isNot(dayBackground));

      p.toggle(); // -> day again
      expect(AppColors.isDark, isFalse);
      expect(AppColors.background, dayBackground);
    });
  });

  group('MortalityProvider', () {
    test('totalCount sums all records', () {
      final p = MortalityProvider();
      p.addRecord(Mortality(
          batchId: 'A', date: DateTime.now(), count: 3,
          cause: MortalityCause.disease));
      p.addRecord(Mortality(
          batchId: 'A', date: DateTime.now(), count: 7,
          cause: MortalityCause.predator));
      expect(p.totalCount, 10);
    });
  });
}
