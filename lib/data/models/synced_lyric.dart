class SyncedLyricLine {
  final Duration timestamp;
  final String text;

  const SyncedLyricLine({
    required this.timestamp,
    required this.text,
  });

  static List<SyncedLyricLine> parseLrc(String lrcContent) {
    final lines = <SyncedLyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regex.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final millis = int.tryParse(match.group(3) ?? '0') ?? 0;
        final text = match.group(4)?.trim() ?? '';

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis < 100 ? millis * 10 : millis,
        );

        if (text.isNotEmpty) {
          lines.add(SyncedLyricLine(timestamp: timestamp, text: text));
        }
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  static int getActiveIndex(List<SyncedLyricLine> lines, Duration currentPosition) {
    if (lines.isEmpty) return -1;
    for (int i = lines.length - 1; i >= 0; i--) {
      if (currentPosition >= lines[i].timestamp) {
        return i;
      }
    }
    return 0;
  }
}
