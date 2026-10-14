/// Decimal-safe money helpers. Amounts are always integer minor units
/// (e.g. halalas for SAR). Binary floating point is never used for money.

const String kDefaultCurrency = 'SAR';

const Map<String, int> _exponents = {
  'SAR': 2,
  'USD': 2,
  'EUR': 2,
  'GBP': 2,
  'AED': 2,
  'QAR': 2,
  'EGP': 2,
  'INR': 2,
  'TRY': 2,
  'CNY': 2,
  'CAD': 2,
  'AUD': 2,
  'CHF': 2,
  'KWD': 3,
  'BHD': 3,
  'OMR': 3,
  'JOD': 3,
  'JPY': 0,
};

const Map<String, String> _arLabels = {
  'SAR': 'ر.س',
  'USD': 'دولار',
  'EUR': 'يورو',
  'GBP': 'جنيه إسترليني',
  'AED': 'درهم',
  'KWD': 'د.ك',
  'BHD': 'د.ب',
  'QAR': 'ر.ق',
  'OMR': 'ر.ع',
  'EGP': 'ج.م',
  'JOD': 'د.أ',
};

List<String> get knownCurrencies => _exponents.keys.toList();

int currencyExponent(String code) => _exponents[code.toUpperCase()] ?? 2;

int _pow10(int e) {
  var r = 1;
  for (var i = 0; i < e; i++) {
    r *= 10;
  }
  return r;
}

/// Parses a number string that has already been digit-normalized
/// (Western digits). Accepts `1,234.50`, `1234.5`, `1234`, `1.234,50`,
/// `12,5`. Returns minor units for [currency] or null if not a number.
int? parseAmountToMinor(String raw, String currency) {
  var s = raw.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(s)) return null;
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String intPart;
  String fracPart = '';
  if (lastDot >= 0 && lastComma >= 0) {
    // Both present: the last one is the decimal separator.
    final decIdx = lastDot > lastComma ? lastDot : lastComma;
    intPart = s.substring(0, decIdx).replaceAll(RegExp(r'[.,]'), '');
    fracPart = s.substring(decIdx + 1);
  } else if (lastComma >= 0) {
    final groups = s.split(',');
    final allThousands = groups.length > 1 &&
        groups.skip(1).every((g) => g.length == 3) &&
        groups.first.isNotEmpty &&
        groups.first.length <= 3;
    if (allThousands) {
      intPart = groups.join();
    } else if (groups.length == 2) {
      intPart = groups[0];
      fracPart = groups[1];
    } else {
      return null;
    }
  } else if (lastDot >= 0) {
    final groups = s.split('.');
    if (groups.length == 2) {
      intPart = groups[0];
      fracPart = groups[1];
    } else if (groups.skip(1).every((g) => g.length == 3) && groups.first.length <= 3) {
      intPart = groups.join(); // 1.234.567 style thousands
    } else {
      return null;
    }
  } else {
    intPart = s;
  }
  if (intPart.isEmpty) intPart = '0';
  if (!RegExp(r'^[0-9]+$').hasMatch(intPart)) return null;
  if (fracPart.isNotEmpty && !RegExp(r'^[0-9]+$').hasMatch(fracPart)) return null;
  if (intPart.length > 13) return null; // unrealistic, avoids overflow

  final e = currencyExponent(currency);
  var frac = fracPart;
  var roundUp = false;
  if (frac.length > e) {
    roundUp = frac.codeUnitAt(e) >= 0x35; // '5'
    frac = frac.substring(0, e);
  }
  frac = frac.padRight(e, '0');
  var minor = int.parse(intPart) * _pow10(e) + (e == 0 ? 0 : int.parse(frac));
  if (roundUp) minor += 1;
  return minor;
}

String _group(int whole) {
  final s = whole.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Plain number text for minor units, e.g. 123450 -> "1,234.50".
String formatMinorNumber(int minor, String currency) {
  final e = currencyExponent(currency);
  final neg = minor < 0;
  final abs = minor.abs();
  final p = _pow10(e);
  final whole = abs ~/ p;
  final frac = abs % p;
  final num = e == 0 ? _group(whole) : '${_group(whole)}.${frac.toString().padLeft(e, '0')}';
  return neg ? '-$num' : num;
}

/// Editable value (no grouping) e.g. 123450 -> "1234.50".
String minorToEditable(int minor, String currency) {
  final e = currencyExponent(currency);
  final p = _pow10(e);
  final abs = minor.abs();
  final s = e == 0 ? '${abs ~/ p}' : '${abs ~/ p}.${(abs % p).toString().padLeft(e, '0')}';
  return minor < 0 ? '-$s' : s;
}

String currencyLabel(String code, {required bool arabic}) {
  final c = code.toUpperCase();
  if (arabic) return _arLabels[c] ?? c;
  return c;
}

/// Money text safe for bidirectional layout: the number is wrapped in a
/// left-to-right isolate so it never gets reordered inside Arabic text.
String formatMoney(int minor, String currency, {required bool arabic}) {
  const lri = '\u2066';
  const pdi = '\u2069';
  final n = formatMinorNumber(minor, currency);
  final label = currencyLabel(currency, arabic: arabic);
  return arabic ? '$lri$n$pdi $label' : '$label $lri$n$pdi';
}

/// Accumulates totals per currency without ever mixing currencies.
class CurrencyTotals {
  final Map<String, int> _byCurrency = {};

  void add(String currency, int minor) {
    final c = currency.toUpperCase();
    _byCurrency[c] = (_byCurrency[c] ?? 0) + minor;
  }

  int of(String currency) => _byCurrency[currency.toUpperCase()] ?? 0;
  bool get isEmpty => _byCurrency.values.every((v) => v == 0);
  Map<String, int> get asMap => Map.unmodifiable(_byCurrency);

  /// Non-default currencies with a non-zero total.
  Map<String, int> foreign([String base = kDefaultCurrency]) => {
        for (final e in _byCurrency.entries)
          if (e.key != base && e.value != 0) e.key: e.value
      };
}
