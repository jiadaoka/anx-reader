enum SceneOrientation {
  auto('auto'),
  portrait('portrait'),
  landscape('landscape');

  const SceneOrientation(this.code);

  final String code;

  static SceneOrientation fromCode(String code) {
    return SceneOrientation.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SceneOrientation.auto,
    );
  }
}
