// The role -> capability matrix that the UI gates on. It mirrors the
// server rules in supabase/h2r_roles_schema.sql; if the two ever drift,
// the app shows actions that silently fail (or hides ones that would
// work), so these assertions are the guard rail.

import 'package:flutter_test/flutter_test.dart';
import 'package:hatch2revenue/utils/caps.dart';

void main() {
  group('Caps role matrix', () {
    // A solo user (no farm) and the owner both have full access.
    for (final full in [const Caps(null), const Caps('owner')]) {
      test('${full.role ?? "solo"} has full access', () {
        expect(full.canAmend, isTrue);
        expect(full.canSeeMoney, isTrue);
        expect(full.canSell, isTrue);
        expect(full.canLogEggs, isTrue);
        expect(full.canLogFeed, isTrue);
        expect(full.canManageVaccines, isTrue);
        expect(full.canRecordDeaths, isTrue);
        expect(full.canManageTeam, isTrue);
        expect(full.canSetPrices, isTrue);
      });
    }

    test('manager is a deputy: books yes, team and prices no', () {
      const m = Caps('manager');
      expect(m.canAmend, isTrue);
      expect(m.canSeeMoney, isTrue);
      expect(m.canSell, isTrue);
      expect(m.canManageVaccines, isTrue);
      expect(m.canManageTeam, isFalse);
      expect(m.canSetPrices, isFalse);
    });

    test('worker: logs and sells, but no money, no edit, no team', () {
      const w = Caps('worker');
      expect(w.canLogEggs, isTrue);
      expect(w.canLogFeed, isTrue);
      expect(w.canRecordDeaths, isTrue);
      expect(w.canSell, isTrue); // Stage 2: workers may record sales
      expect(w.canSeeEggs, isTrue);
      // Denied:
      expect(w.canAmend, isFalse); // append-only
      expect(w.canSeeMoney, isFalse); // no totals/profit/ledger
      expect(w.canManageVaccines, isFalse); // view schedule only
      expect(w.canEditDeaths, isFalse);
      expect(w.canManageTeam, isFalse);
      expect(w.canSetPrices, isFalse);
    });

    test('vet: health only, no eggs, no money, no sales', () {
      const v = Caps('vet');
      expect(v.canManageVaccines, isTrue);
      expect(v.canRecordDeaths, isTrue);
      expect(v.canEditDeaths, isTrue); // annotate cause of death
      // Denied:
      expect(v.canSeeEggs, isFalse);
      expect(v.canLogEggs, isFalse);
      expect(v.canLogFeed, isFalse); // reads feed, does not log it
      expect(v.canSell, isFalse);
      expect(v.canSeeMoney, isFalse);
      expect(v.canAmend, isFalse);
      expect(v.canManageTeam, isFalse);
    });

    test('an unknown/pending role is treated as no farm access', () {
      // Should not throw, and should not grant amend/money.
      const unknown = Caps('something');
      expect(unknown.canAmend, isFalse);
      expect(unknown.canSeeMoney, isFalse);
    });
  });
}
