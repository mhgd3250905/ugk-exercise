class AppReleaseInfo {
  const AppReleaseInfo({
    required this.versionCode,
    required this.versionName,
    required this.releaseNotes,
  });

  final int versionCode;
  final String versionName;
  final List<String> releaseNotes;

  factory AppReleaseInfo.fromApiJson(Map<String, Object?> json) {
    final latest = json['latest'];
    if (json['schemaVersion'] != 1 ||
        json['platform'] != 'android' ||
        (json['locale'] != 'zh' && json['locale'] != 'en') ||
        latest is! Map) {
      throw const FormatException('Invalid app update response');
    }

    final parsed = Map<String, Object?>.from(latest);
    final versionCode = parsed['versionCode'];
    final versionName = parsed['versionName'];
    final releaseNotes = parsed['releaseNotes'];
    if (versionCode is! int ||
        versionCode <= 0 ||
        versionName is! String ||
        versionName.isEmpty ||
        versionName != versionName.trim() ||
        versionName.length > 32 ||
        releaseNotes is! List ||
        releaseNotes.isEmpty ||
        releaseNotes.length > 6) {
      throw const FormatException('Invalid app update response');
    }

    final notes = <String>[];
    for (final note in releaseNotes) {
      if (note is! String ||
          note.isEmpty ||
          note != note.trim() ||
          note.length > 160) {
        throw const FormatException('Invalid app update response');
      }
      notes.add(note);
    }
    return AppReleaseInfo(
      versionCode: versionCode,
      versionName: versionName,
      releaseNotes: List.unmodifiable(notes),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AppReleaseInfo ||
        versionCode != other.versionCode ||
        versionName != other.versionName ||
        releaseNotes.length != other.releaseNotes.length) {
      return false;
    }
    for (var index = 0; index < releaseNotes.length; index += 1) {
      if (releaseNotes[index] != other.releaseNotes[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(versionCode, versionName, Object.hashAll(releaseNotes));
}
