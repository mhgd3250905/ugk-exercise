abstract class VoicePromptPort {
  VoicePromptPort({this.baseDir = ''});

  final String baseDir;

  Future<void> playGuide();

  Future<void> playReady();

  Future<void> playPoseLost();

  Future<void> playTooClose();

  Future<void> playNarrowForm();

  Future<void> playCount(int count);

  Future<void> preloadCounts();

  Future<void> stop();

  Future<void> dispose();
}
