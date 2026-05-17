import 'dart:io';

/// Splits a large audio file into byte-boundary chunks so each chunk stays
/// below Groq's 25 MB hard limit.
///
/// Returns the source file as a single-element list when it already fits
/// within [maxBytes] — no temp files are created in that case.
/// Chunk files must be deleted by the caller via [cleanup] after use.
class AudioChunker {
  /// 20 MB per chunk — 5 MB headroom below Groq's 25 MB hard limit.
  static const int defaultMaxBytes = 20 * 1024 * 1024;

  /// Chunks [source] into files of at most [maxBytes].
  /// Writes temp files to [tempDir] (falls back to [Directory.systemTemp]).
  static Future<List<File>> chunk(
    File source, {
    int maxBytes = defaultMaxBytes,
    Directory? tempDir,
  }) async {
    final fileSize = await source.length();
    if (fileSize <= maxBytes) return [source];

    final dir = tempDir ?? Directory.systemTemp;
    final stem = source.uri.pathSegments.last;
    final chunks = <File>[];
    var offset = 0;
    var index = 0;

    while (offset < fileSize) {
      final end = (offset + maxBytes).clamp(0, fileSize) as int;
      final chunkFile = File('${dir.path}/adc_chunk_${index}_$stem');
      final sink = chunkFile.openWrite();
      try {
        await source.openRead(offset, end).pipe(sink);
      } finally {
        await sink.close();
      }
      chunks.add(chunkFile);
      offset = end;
      index++;
    }
    return chunks;
  }

  /// Deletes chunk temp files produced by [chunk] that differ from [source].
  static Future<void> cleanup(File source, List<File> chunks) async {
    for (final c in chunks) {
      if (c.path == source.path) continue;
      try {
        await c.delete();
      } catch (_) {}
    }
  }
}
