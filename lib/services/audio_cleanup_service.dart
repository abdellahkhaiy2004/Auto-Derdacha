import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Deletes audio files in `<docs>/audio/` that are not referenced by any
/// meeting row AND are older than 24 hours ([IP-0051]).
///
/// The 24-hour age guard ensures that a file being actively recorded (whose
/// path was generated moments ago) is never deleted, even if the DB row has
/// not been inserted yet.
class AudioCleanupService {
  const AudioCleanupService._();

  /// [referencedPaths] is the set of all `audioPath` values from the DB.
  /// Returns the number of orphan files deleted.
  static Future<int> run(Set<String> referencedPaths) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${docsDir.path}/audio');
    if (!audioDir.existsSync()) return 0;

    var deleted = 0;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    await for (final entity in audioDir.list()) {
      if (entity is! File) continue;
      if (referencedPaths.contains(entity.path)) continue;
      try {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
          deleted++;
        }
      } catch (_) {}
    }
    return deleted;
  }
}
