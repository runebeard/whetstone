class AppSettings {
  final bool onboardingComplete;
  final bool sampleCharactersEnabled;

  const AppSettings({
    this.onboardingComplete = false,
    this.sampleCharactersEnabled = false,
  });

  AppSettings copyWith({
    bool? onboardingComplete,
    bool? sampleCharactersEnabled,
  }) {
    return AppSettings(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      sampleCharactersEnabled:
          sampleCharactersEnabled ?? this.sampleCharactersEnabled,
    );
  }

  Map<String, Object> toJson() {
    return {
      'schemaVersion': 1,
      'onboardingComplete': onboardingComplete,
      'sampleCharactersEnabled': sampleCharactersEnabled,
    };
  }

  factory AppSettings.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported app settings version.');
    }
    return AppSettings(
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      sampleCharactersEnabled:
          json['sampleCharactersEnabled'] as bool? ?? false,
    );
  }
}
