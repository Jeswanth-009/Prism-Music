/// Reverb presets matching Android PresetReverb API
enum ReverbPreset {
  none('NONE', 'None'),
  smallRoom('SMALLROOM', 'Small Room'),
  mediumRoom('MEDIUMROOM', 'Medium Room'),
  largeRoom('LARGEROOM', 'Large Room'),
  mediumHall('MEDIUMHALL', 'Medium Hall'),
  largeHall('LARGEHALL', 'Large Hall'),
  plate('PLATE', 'Plate');

  final String value;
  final String displayName;

  const ReverbPreset(this.value, this.displayName);

  static ReverbPreset fromString(String value) {
    return ReverbPreset.values.firstWhere(
      (preset) => preset.value == value,
      orElse: () => ReverbPreset.none,
    );
  }
}
