/// Compact relative-time formatting for feed/chat timestamps (e.g. "2h",
/// "5d"). Falls back to an absolute short date beyond a week.
extension RelativeTimeX on DateTime {
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(this);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}';
  }

  /// Clock time like "9:05 PM" — used on chat bubbles, where the day/date lives
  /// in the date separator header so every message just needs its time.
  String get clockTime {
    final l = toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    return '$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
  }
}
