/// Tiny date formatter (no `intl` dependency). Locale-agnostic short form, e.g.
/// `Jan 5, 2026`.
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// `JUN` — the month mark on a date chip.
String monthAbbrev(DateTime d) => _months[d.month - 1].toUpperCase();

/// `8:02 AM` — 12-hour clock. Locale-agnostic, like the rest of this file.
String clockTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// `Jun 15, 2026 at 8:02 AM` — how the history rows stamp an event.
String dateAtTime(DateTime d) => '${shortDate(d)} at ${clockTime(d)}';
