class CurrencyFormatter {
  static const String currencySymbol = '₵';
  static const String currencyName = 'GHS';

  static String format(double amount) {
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }

  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '$currencySymbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$currencySymbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  static double? parse(String value) {
    try {
      return double.parse(
        value.replaceAll(currencySymbol, '').replaceAll(',', ''),
      );
    } catch (e) {
      return null;
    }
  }
}
