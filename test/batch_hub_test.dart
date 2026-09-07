// Batch hub tests.
//
// The farmer's complaint this feature answers: when logging feed, eggs
// or a vaccination from a module tab, it is easy to file the record
// against the wrong flock, because the batch is just one dropdown among
// several. Opening a batch and acting from there removes the choice.
//
// These tests check the two things that matter: the hub offers every
// action for the batch you opened, and the forms it opens have that
// batch fixed rather than selectable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hatch2revenue/models/batch.dart';
import 'package:hatch2revenue/models/egg_production.dart';
import 'package:hatch2revenue/models/mortality.dart';
import 'package:hatch2revenue/providers/batch_provider.dart';
import 'package:hatch2revenue/providers/egg_production_provider.dart';
import 'package:hatch2revenue/providers/feed_provider.dart';
import 'package:hatch2revenue/providers/mortality_provider.dart';
import 'package:hatch2revenue/providers/vaccination_provider.dart';
import 'package:hatch2revenue/providers/poultry_house_provider.dart';
import 'package:hatch2revenue/providers/measurement_provider.dart';
import 'package:hatch2revenue/screens/lifecycle/batch_detail_screen.dart';
import 'package:hatch2revenue/utils/html_widgets.dart';

/// Builds the hub for [batch] with the providers it watches.
Widget _hub({
  required Batch batch,
  required BatchProvider batches,
  EggProductionProvider? eggs,
  FeedProvider? feed,
  MortalityProvider? mortality,
  VaccinationProvider? vaccination,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: batches),
      ChangeNotifierProvider.value(value: eggs ?? EggProductionProvider()),
      ChangeNotifierProvider.value(value: feed ?? FeedProvider()),
      ChangeNotifierProvider.value(value: mortality ?? MortalityProvider()),
      ChangeNotifierProvider.value(
          value: vaccination ?? VaccinationProvider()),
      ChangeNotifierProvider(create: (_) => PoultryHouseProvider()),
      ChangeNotifierProvider(create: (_) => MeasurementProvider()),
    ],
    child: MaterialApp(home: BatchDetailScreen(batchId: batch.id)),
  );
}

Batch _layerHouse() => Batch(
      id: 'batch-1',
      name: 'Layer House A',
      type: BatchType.layers,
      initialCount: 500,
      currentCount: 486,
      hatchDate: DateTime.now().subtract(const Duration(days: 200)),
      source: 'Akate Farms',
    );

void main() {
  group('batch hub', () {
    // The hub is a long scrolling page and ListView only builds what is
    // on screen, so give the test surface room to render all of it.
    setUp(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
      view.physicalSize = const Size(1200, 3200);
      view.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
    testWidgets('offers every action for the opened batch', (tester) async {
      final batch = _layerHouse();
      final batches = BatchProvider()..addBatch(batch);

      await tester.pumpWidget(_hub(batch: batch, batches: batches));
      await tester.pumpAndSettle();

      expect(find.text('Layer House A'), findsWidgets); // app bar title
      expect(find.text('Log eggs'), findsOneWidget);
      expect(find.text('Log feed'), findsOneWidget);
      expect(find.text('Record deaths'), findsOneWidget);
      expect(find.text('Schedule vaccine'), findsOneWidget);
    });

    testWidgets('shows only this batch\'s records', (tester) async {
      final batch = _layerHouse();
      final batches = BatchProvider()..addBatch(batch);

      final eggs = EggProductionProvider()
        ..addRecord(EggProduction(
          batchId: 'batch-1',
          date: DateTime.now(),
          eggCount: 420,
          pricePerEgg: 1.2,
        ))
        // Belongs to a different flock and must not appear here.
        ..addRecord(EggProduction(
          batchId: 'batch-2',
          date: DateTime.now(),
          eggCount: 999,
          pricePerEgg: 1.2,
        ));

      final deaths = MortalityProvider()
        ..addRecord(Mortality(
          batchId: 'batch-1',
          date: DateTime.now(),
          count: 14,
        ));

      await tester.pumpWidget(_hub(
        batch: batch,
        batches: batches,
        eggs: eggs,
        mortality: deaths,
      ));
      await tester.pumpAndSettle();

      // 420 eggs is 14 crates; the other flock's 999 must be absent.
      expect(find.textContaining('14'), findsWidgets);
      expect(find.textContaining('999'), findsNothing);
      expect(find.textContaining('33.3'), findsNothing); // 999 in crates
    });

    testWidgets('empty sections say so instead of showing nothing',
        (tester) async {
      final batch = _layerHouse();
      final batches = BatchProvider()..addBatch(batch);

      await tester.pumpWidget(_hub(batch: batch, batches: batches));
      await tester.pumpAndSettle();

      expect(find.text('No eggs logged for this batch yet.'), findsOneWidget);
      expect(find.text('No feed logged for this batch yet.'), findsOneWidget);
      expect(find.text('No deaths recorded for this batch.'), findsOneWidget);
      expect(find.text('No vaccines scheduled for this batch yet.'),
          findsOneWidget);
    });

    testWidgets('logging eggs from the hub locks the flock', (tester) async {
      final batch = _layerHouse();
      final batches = BatchProvider()..addBatch(batch);

      await tester.pumpWidget(_hub(batch: batch, batches: batches));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log eggs'));
      await tester.pumpAndSettle();

      expect(find.text('Log Egg Production'), findsOneWidget);
      // The flock is fixed and shown locked, NOT offered as a dropdown.
      expect(find.byType(LockedBatchField), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('scheduling a vaccine from the hub locks the flock',
        (tester) async {
      final batch = _layerHouse();
      final batches = BatchProvider()..addBatch(batch);

      await tester.pumpWidget(_hub(batch: batch, batches: batches));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Schedule vaccine'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Vaccine'), findsOneWidget);
      expect(find.byType(LockedBatchField), findsOneWidget);
      // One String dropdown remains, but it is the route of
      // administration, not a batch picker.
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('Drinking Water'), findsOneWidget);
      // No 'All' option means the flock genuinely cannot be changed.
      expect(find.text('All'), findsNothing);
    });

    testWidgets('recording deaths from the hub locks the flock',
        (tester) async {
      final batch = _layerHouse();
      final batches = BatchProvider()..addBatch(batch);

      await tester.pumpWidget(_hub(batch: batch, batches: batches));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record deaths'));
      await tester.pumpAndSettle();

      expect(find.text('Log Mortality'), findsOneWidget);
      expect(find.byType(LockedBatchField), findsOneWidget);
      // Cause of death is still a dropdown; only the BATCH is locked.
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('a deleted batch does not crash the hub', (tester) async {
      final batch = _layerHouse();
      final batches = BatchProvider(); // never added

      await tester.pumpWidget(_hub(batch: batch, batches: batches));
      await tester.pumpAndSettle();

      expect(find.text('This batch no longer exists.'), findsOneWidget);
    });
  });
}
