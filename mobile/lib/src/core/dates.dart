/// Tiny date formatter (no `intl` dependency). Locale-agnostic short form, e.g.
/// `Jan 5, 2026`.
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
