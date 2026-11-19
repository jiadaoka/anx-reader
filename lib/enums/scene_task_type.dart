enum SceneTaskType {
  prompt('prompt'),
  image('image');

  const SceneTaskType(this.code);

  final String code;

  static SceneTaskType fromCode(String code) {
    return SceneTaskType.values
        .firstWhere((e) => e.code == code, orElse: () => SceneTaskType.prompt);
  }
}
