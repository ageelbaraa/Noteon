import '../data/note.dart';

/// Buckets used to group the notes list by [Note.updatedAt].
enum NoteDateBucket { today, yesterday, thisWeek, older }

/// A labeled slice of notes for one date bucket.
class NoteDateSection {
  const NoteDateSection({required this.bucket, required this.notes});

  final NoteDateBucket bucket;
  final List<Note> notes;
}

/// Groups notes into Today / Yesterday / This week / Older.
abstract final class NoteDateGrouper {
  static List<NoteDateSection> group(
    List<Note> notes, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final buckets = <NoteDateBucket, List<Note>>{
      NoteDateBucket.today: <Note>[],
      NoteDateBucket.yesterday: <Note>[],
      NoteDateBucket.thisWeek: <Note>[],
      NoteDateBucket.older: <Note>[],
    };

    for (final note in notes) {
      final updated = DateTime(
        note.updatedAt.year,
        note.updatedAt.month,
        note.updatedAt.day,
      );
      final bucket = bucketFor(
        updated,
        today: today,
        yesterday: yesterday,
        weekStart: weekStart,
      );
      buckets[bucket]!.add(note);
    }

    return NoteDateBucket.values
        .where((bucket) => buckets[bucket]!.isNotEmpty)
        .map(
          (bucket) => NoteDateSection(bucket: bucket, notes: buckets[bucket]!),
        )
        .toList(growable: false);
  }

  static NoteDateBucket bucketFor(
    DateTime day, {
    required DateTime today,
    required DateTime yesterday,
    required DateTime weekStart,
  }) {
    if (!day.isBefore(today)) {
      return NoteDateBucket.today;
    }
    if (!day.isBefore(yesterday)) {
      return NoteDateBucket.yesterday;
    }
    if (!day.isBefore(weekStart)) {
      return NoteDateBucket.thisWeek;
    }
    return NoteDateBucket.older;
  }
}
