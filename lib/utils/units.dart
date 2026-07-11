/// Farm units used across Hatch2Revenue.
///
/// Eggs are counted in CRATES (a crate holds 30 eggs). Feed is bought
/// and used in BAGS (a bag is 50 kg). Records still store the raw base
/// unit (individual eggs, kilograms) so nothing breaks, but the UI is
/// expressed in the units farmers actually use.
class Units {
  static const int eggsPerCrate = 30;
  static const double kgPerBag = 50;

  // --- Eggs ↔ crates ------------------------------------------------

  /// Eggs → crates as a decimal (e.g. 45 eggs → 1.5 crates).
  static double eggsToCrates(int eggs) => eggs / eggsPerCrate;

  static int cratesToEggs(double crates) => (crates * eggsPerCrate).round();

  /// Human label like "12 crates" or "12 crates 5" (12 crates + 5 loose).
  static String crateLabel(int eggs) {
    final crates = eggs ~/ eggsPerCrate;
    final loose = eggs % eggsPerCrate;
    if (loose == 0) return '$crates ${crates == 1 ? "crate" : "crates"}';
    return '$crates ${crates == 1 ? "crate" : "crates"} $loose';
  }

  /// Short crate value, one decimal (e.g. "12.2").
  static String crateShort(int eggs) => eggsToCrates(eggs).toStringAsFixed(1);

  // --- Feed ↔ bags --------------------------------------------------

  static double kgToBags(double kg) => kg / kgPerBag;

  static double bagsToKg(double bags) => bags * kgPerBag;

  /// Short bag value, one decimal (e.g. "3.5").
  static String bagShort(double kg) => kgToBags(kg).toStringAsFixed(1);
}
