/// Calendar-day value type (no time, no time zone).
///
/// All date-only fields (due dates, follow-up dates, habit days) use [Day]
/// and are stored in SQLite as ISO strings (`yyyy-MM-dd`). Arithmetic is done
/// in UTC so daylight-saving transitions can never shift a day.
class Day implements Comparable<Day> {
  final int year;
  final int month;
  final int day;

  const Day(this.year, this.month, this.day);

  factory Day.fromDateTime(DateTime d) => Day(d.year, d.month, d.day);

  /// Today according to [AppClock].
  factory Day.today() => Day.fromDateTime(AppClock.now());

  static Day parse(String s) {
    final parts = s.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid day: $s');
    }
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    if (m < 1 || m > 12 || d < 1 || d > daysInMonthOf(y, m)) {
      throw FormatException('Invalid day: $s');
    }
    return Day(y, m, d);
  }

  static Day? tryParse(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return parse(s);
    } catch (_) {
      return null;
    }
  }

  static int daysInMonthOf(int year, int month) {
    final next = month == 12 ? DateTime.utc(year + 1, 1, 1) : DateTime.utc(year, month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  DateTime get _utc => DateTime.utc(year, month, day);

  Day addDays(int n) {
    final d = _utc.add(Duration(days: n));
    return Day(d.year, d.month, d.day);
  }

  Day addMonths(int n) {
    var m = month - 1 + n;
    var y = year + (m ~/ 12);
    m = m % 12;
    if (m < 0) {
      m += 12;
      y -= 1;
    }
    final maxDay = daysInMonthOf(y, m + 1);
    return Day(y, m + 1, day > maxDay ? maxDay : day);
  }

  Day get firstOfMonth => Day(year, month, 1);
  int get daysInMonth => daysInMonthOf(year, month);

  /// Number of days from [other] to this day (positive if this is later).
  int differenceInDays(Day other) => _utc.difference(other._utc).inDays;

  /// ISO weekday: 1 = Monday ... 7 = Sunday.
  int get weekday => _utc.weekday;

  /// 0 = Sunday ... 6 = Saturday. Used for weekday bitmasks.
  int get weekdayIndex => weekday % 7;

  bool isBefore(Day o) => compareTo(o) < 0;
  bool isAfter(Day o) => compareTo(o) > 0;
  bool isSameOrBefore(Day o) => compareTo(o) <= 0;
  bool isSameOrAfter(Day o) => compareTo(o) >= 0;

  /// Local DateTime at [minutes] past midnight.
  DateTime atMinutes(int minutes) => DateTime(year, month, day, minutes ~/ 60, minutes % 60);

  DateTime get startLocal => DateTime(year, month, day);
  DateTime get endLocalExclusive => addDays(1).startLocal;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => toIso();

  @override
  int compareTo(Day other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is Day && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Injectable clock so domain logic can be tested deterministically.
class AppClock {
  static DateTime Function() now = DateTime.now;
}

/// Inclusive day range.
class DayRange {
  final Day start;
  final Day end;
  const DayRange(this.start, this.end);

  bool contains(Day d) => d.isSameOrAfter(start) && d.isSameOrBefore(end);
  int get lengthInDays => end.differenceInDays(start) + 1;

  Iterable<Day> get days sync* {
    var d = start;
    while (d.isSameOrBefore(end)) {
      yield d;
      d = d.addDays(1);
    }
  }

  int get startMillis => start.startLocal.millisecondsSinceEpoch;
  int get endMillisExclusive => end.endLocalExclusive.millisecondsSinceEpoch;
}

/// First day of the week containing [d]. [weekStart] uses 0 = Sunday ... 6 = Saturday.
Day startOfWeek(Day d, int weekStart) {
  final diff = (d.weekdayIndex - weekStart + 7) % 7;
  return d.addDays(-diff);
}
