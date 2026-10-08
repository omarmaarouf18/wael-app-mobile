import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Notification timestamps (owner decision 2026-10-08, CONTENT-GAPS #32).
///
/// Recent times render relative ("الآن", "منذ ٥ دقائق", "منذ ساعتين",
/// "أمس"); older ones render a date ("٨ أكتوبر ٢٠٢٦، ٣:٤٠ م" /
/// "8 Oct 2026, 3:40 PM"). All calendar math uses Africa/Cairo wall time.
/// Anything unparsable falls back to the raw string, never a crash.
///
/// intl date data must be loaded once before the first formatted date
/// (see [ensureNotificationTimeInitialized], called from `main()` and the
/// test bootstrap); if it was missed, dates fall back to raw as well.
bool _dateDataReady = false;

/// Loads intl date symbols (all locales, bundled, offline-safe). Safe to
/// call more than once; cheap after the first load.
Future<void> ensureNotificationTimeInitialized() async {
  if (_dateDataReady) return;
  await initializeDateFormatting();
  _dateDataReady = true;
}

/// Africa/Cairo UTC offset in whole hours for [utc].
///
/// Egypt observes daylight saving from 00:00 on the last Friday of April
/// until 24:00 on the last Thursday of October (UTC+3 inside the window,
/// UTC+2 outside). If the law ever changes, only this function needs an
/// update.
int cairoOffsetHours(DateTime utc) {
  DateTime lastWeekday(int year, int month, int weekday) {
    // Day 0 of next month is the last day of this month.
    var day = DateTime.utc(year, month + 1, 0);
    while (day.weekday != weekday) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }

  final start = lastWeekday(utc.year, DateTime.april, DateTime.friday);
  final startUtc = DateTime.utc(
    start.year,
    start.month,
    start.day,
  ).subtract(const Duration(hours: 2));
  // 24:00 on the last Thursday is 00:00 the next day, still +03:00.
  final endDay = lastWeekday(
    utc.year,
    DateTime.october,
    DateTime.thursday,
  ).add(const Duration(days: 1));
  final endUtc = DateTime.utc(
    endDay.year,
    endDay.month,
    endDay.day,
  ).subtract(const Duration(hours: 3));
  if (!utc.isBefore(startUtc) && utc.isBefore(endUtc)) return 3;
  return 2;
}

/// [utc] shifted to Africa/Cairo wall time (kept on a UTC anchor; only
/// the calendar fields are read from the result).
DateTime cairoWallTime(DateTime utc) =>
    utc.toUtc().add(Duration(hours: cairoOffsetHours(utc.toUtc())));

const _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

/// ASCII digits rendered as Arabic-Indic (٥٩ not 59).
String _arabicDigits(int n) => _arabicDigitsIn(n.toString());

/// Every ASCII digit in [s] rendered as Arabic-Indic; other characters
/// (month names, day periods, punctuation) pass through untouched.
String _arabicDigitsIn(String s) => s.split('').map((c) {
  final d = int.tryParse(c);
  return d == null ? c : _arabicIndicDigits[d];
}).join();

String _minutesAgo(int m, bool isArabic) {
  if (!isArabic) return m == 1 ? '1 minute ago' : '$m minutes ago';
  if (m == 1) return 'منذ دقيقة';
  if (m == 2) return 'منذ دقيقتين';
  if (m <= 10) return 'منذ ${_arabicDigits(m)} دقائق';
  return 'منذ ${_arabicDigits(m)} دقيقة';
}

String _hoursAgo(int h, bool isArabic) {
  if (!isArabic) return h == 1 ? '1 hour ago' : '$h hours ago';
  if (h == 1) return 'منذ ساعة';
  if (h == 2) return 'منذ ساعتين';
  if (h <= 10) return 'منذ ${_arabicDigits(h)} ساعات';
  return 'منذ ${_arabicDigits(h)} ساعة';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Formats a raw `created_at` string for the notifications list.
///
/// Durations under 24 hours render relative to [clock] (default
/// `DateTime.now()`); older times render a calendar date, with "yesterday"
/// ("أمس" / "Yesterday") as the special case. Unparsable input (and
/// missing intl date data) returns [raw] unchanged.
String formatNotificationTime(
  String raw, {
  required bool isArabic,
  DateTime? clock,
}) {
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return raw;
  final now = (clock ?? DateTime.now()).toUtc();
  var created = parsed.toUtc();
  if (created.isAfter(now)) created = now;

  final diff = now.difference(created);
  if (diff.inSeconds < 60) return isArabic ? 'الآن' : 'Just now';
  if (diff.inMinutes < 60) return _minutesAgo(diff.inMinutes, isArabic);
  if (diff.inHours < 24) return _hoursAgo(diff.inHours, isArabic);

  final createdCairo = cairoWallTime(created);
  final nowCairo = cairoWallTime(now);
  final yesterday = nowCairo.subtract(const Duration(days: 1));
  if (_sameDay(createdCairo, yesterday)) {
    return isArabic ? 'أمس' : 'Yesterday';
  }
  try {
    if (isArabic) {
      // intl renders the Arabic month name and day period, but day/year/
      // time digits come out ASCII: convert them to Arabic-Indic to match
      // the approved "٨ أكتوبر ٢٠٢٦، ٣:٤٠ م" shape.
      final shaped = DateFormat(
        'd MMMM yyyy، h:mm a',
        'ar',
      ).format(createdCairo);
      return _arabicDigitsIn(shaped);
    }
    return DateFormat('d MMM yyyy, h:mm a', 'en').format(createdCairo);
  } catch (_) {
    return raw;
  }
}
