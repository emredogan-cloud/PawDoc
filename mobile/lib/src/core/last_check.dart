/// Human-readable recency label for the home hero "Last check" line (M0 F-2).
/// Pure so it is trivially unit-testable; [now] is injectable for tests.
String lastCheckLabel(DateTime checkedAt, {DateTime? now}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final checked = checkedAt.toUtc();
  final diff = reference.difference(checked);
  // Clock skew between device and server can make a fresh row look like the
  // future — that is still "just now", never a negative duration.
  if (diff < const Duration(minutes: 2)) return 'just now';
  if (diff < const Duration(hours: 1)) return '${diff.inMinutes} min ago';
  if (diff < const Duration(hours: 24)) return '${diff.inHours} h ago';
  if (diff < const Duration(days: 2)) return 'yesterday';
  if (diff < const Duration(days: 7)) return '${diff.inDays} days ago';
  if (diff < const Duration(days: 30)) return '${diff.inDays ~/ 7} wk ago';
  if (diff < const Duration(days: 365)) return '${diff.inDays ~/ 30} mo ago';
  return '${diff.inDays ~/ 365} yr ago';
}
