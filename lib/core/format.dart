import 'day.dart';
import 'strings.dart';

const _arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];
const _enMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November',
  'December'
];
const _enMonthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// Index 0 = Sunday.
const _arWeekdays = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const _arWeekdaysShort = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
const _enWeekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const _enWeekdaysShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

bool get _ar => S.current.isArabic;

String monthName(int month) => _ar ? _arMonths[month - 1] : _enMonths[month - 1];

String monthYear(Day d) => '${monthName(d.month)} ${d.year}';

/// Weekday name for index 0 = Sunday ... 6 = Saturday.
String weekdayName(int index, {bool short = false}) =>
    _ar ? (short ? _arWeekdaysShort : _arWeekdays)[index] : (short ? _enWeekdaysShort : _enWeekdays)[index];

/// Very short weekday label (calendar header).
String weekdayInitial(int index) =>
    _ar ? const ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'][index] : _enWeekdaysShort[index].substring(0, 2);

/// "14 أكتوبر" / "Oct 14", with the year when not the current year.
String formatDayShort(Day d, {Day? today}) {
  final t = today ?? Day.today();
  final withYear = d.year != t.year;
  if (_ar) return withYear ? '${d.day} ${_arMonths[d.month - 1]} ${d.year}' : '${d.day} ${_arMonths[d.month - 1]}';
  return withYear ? '${_enMonthsShort[d.month - 1]} ${d.day}, ${d.year}' : '${_enMonthsShort[d.month - 1]} ${d.day}';
}

/// Relative label when close to today ("اليوم", "غداً", "أمس"), else short date.
String formatDayRelative(Day d, {Day? today}) {
  final t = today ?? Day.today();
  final diff = d.differenceInDays(t);
  if (diff == 0) return S.current.today;
  if (diff == 1) return S.current.tomorrow;
  if (diff == -1) return S.current.yesterday;
  return formatDayShort(d, today: t);
}

String formatDayLong(Day d) {
  final wd = weekdayName(d.weekdayIndex);
  if (_ar) return '$wd، ${d.day} ${_arMonths[d.month - 1]} ${d.year}';
  return '$wd, ${_enMonths[d.month - 1]} ${d.day}, ${d.year}';
}

/// "3:05 م" / "3:05 PM". Wrapped in an LTR isolate so it never reorders.
String formatMinutes(int minutes) {
  final h24 = minutes ~/ 60;
  final m = minutes % 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final pm = h24 >= 12;
  final suffix = _ar ? (pm ? 'م' : 'ص') : (pm ? 'PM' : 'AM');
  return '⁦$h12:${m.toString().padLeft(2, '0')}⁩ $suffix';
}

String formatTimeOf(DateTime dt) => formatMinutes(dt.hour * 60 + dt.minute);

String formatDateTimeMs(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${formatDayShort(Day.fromDateTime(dt))} · ${formatTimeOf(dt)}';
}

/// Wraps text that may be Latin (merchant names, codes) so it lays out
/// correctly inside Arabic sentences.
String isolate(String s) => '⁨$s⁩';

/// Masked card / account: "•••• 1234".
String maskAccount(String last4) => last4.isEmpty ? '' : '⁦•••• $last4⁩';
