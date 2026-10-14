/// SMS text normalization.
///
/// Produces two strings of identical length:
///  * [NormalizedSms.text]  - display text: Western digits, unified separators,
///    collapsed whitespace, diacritics/tatweel/bidi marks removed.
///  * [NormalizedSms.match] - same text, lowercased (Latin) with Arabic letter
///    variants folded (أ إ آ ٱ -> ا, ى -> ي, ة -> ه).
/// Because the second mapping is 1:1, an index found in [match] is valid in
/// [text], so extracted values (merchant names) keep their original spelling.
class NormalizedSms {
  final String text;
  final String match;
  const NormalizedSms(this.text, this.match);
}

bool _isRemovable(int r) {
  if (r == 0x0640) return true; // tatweel
  if (r >= 0x064B && r <= 0x0652) return true; // harakat
  if (r == 0x0670) return true; // superscript alef
  if (r >= 0x200B && r <= 0x200F) return true; // zero width, LRM/RLM
  if (r >= 0x202A && r <= 0x202E) return true; // bidi embeddings
  if (r >= 0x2066 && r <= 0x2069) return true; // bidi isolates
  if (r == 0xFEFF) return true;
  return false;
}

bool _isSpaceLike(int r) =>
    r == 0x20 || r == 0x09 || r == 0xA0 || (r >= 0x2000 && r <= 0x200A) || r == 0x202F || r == 0x3000;

int _mapChar(int r) {
  if (r >= 0x0660 && r <= 0x0669) return 0x30 + (r - 0x0660); // Arabic-Indic digits
  if (r >= 0x06F0 && r <= 0x06F9) return 0x30 + (r - 0x06F0); // Extended (Persian) digits
  switch (r) {
    case 0x066B: // Arabic decimal separator
      return 0x2E;
    case 0x066C: // Arabic thousands separator
      return 0x2C;
    case 0x060C: // Arabic comma
      return 0x2C;
    case 0x061B: // Arabic semicolon
      return 0x3B;
    case 0x066A: // Arabic percent
      return 0x25;
    case 0x2212: // minus sign
    case 0x2013:
    case 0x2014:
      return 0x2D;
    case 0xFF1A: // fullwidth colon
      return 0x3A;
  }
  return r;
}

/// 1:1 folding used for matching.
int foldForMatch(int r) {
  if (r >= 0x41 && r <= 0x5A) return r + 0x20; // A-Z
  switch (r) {
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0622: // آ
    case 0x0671: // ٱ
      return 0x0627; // ا
    case 0x0649: // ى
      return 0x064A; // ي
    case 0x0629: // ة
      return 0x0647; // ه
  }
  return r;
}

/// Applies [foldForMatch] to a whole string (used for keywords).
String foldString(String s) => String.fromCharCodes(s.runes.map(foldForMatch));

NormalizedSms normalizeSms(String body) {
  final out = <int>[];
  var lastWasSpace = false;
  var lastWasNewline = true; // trims leading whitespace
  final src = body.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final raw in src.runes) {
    if (_isRemovable(raw)) continue;
    if (raw == 0x0A) {
      // Trim trailing space before newline and collapse blank lines.
      while (out.isNotEmpty && out.last == 0x20) {
        out.removeLast();
      }
      if (!lastWasNewline) out.add(0x0A);
      lastWasNewline = true;
      lastWasSpace = false;
      continue;
    }
    if (_isSpaceLike(raw)) {
      if (!lastWasSpace && !lastWasNewline) out.add(0x20);
      lastWasSpace = true;
      continue;
    }
    out.add(_mapChar(raw));
    lastWasSpace = false;
    lastWasNewline = false;
  }
  while (out.isNotEmpty && (out.last == 0x20 || out.last == 0x0A)) {
    out.removeLast();
  }
  final text = String.fromCharCodes(out);
  final match = String.fromCharCodes(out.map(foldForMatch));
  return NormalizedSms(text, match);
}
