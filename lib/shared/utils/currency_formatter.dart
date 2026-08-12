/// Maps the supported currency codes to their display symbol. Kept small and
/// centralized so `Settings > Currency` can drive display formatting without
/// touching each screen's financial calculations.
class CurrencyFormatter {
  CurrencyFormatter._();

  static const Map<String, String> symbols = {
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
  };

  static const List<String> supportedCurrencies = ['INR', 'USD', 'EUR', 'GBP'];

  static String symbolFor(String currencyCode) {
    return symbols[currencyCode] ?? symbols['INR']!;
  }

  static String format(double amount, String currencyCode) {
    return '${symbolFor(currencyCode)}${amount.toStringAsFixed(0)}';
  }
}
