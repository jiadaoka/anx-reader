enum SceneTaskStatus {
  queued('queued'),
  running('running'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  const SceneTaskStatus(this.code);

  final String code;

  static SceneTaskStatus fromCode(String code) {
    return SceneTaskStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SceneTaskStatus.queued,
    );
  }

  bool get isFinished =>
      this == SceneTaskStatus.completed ||
      this == SceneTaskStatus.failed ||
      this == SceneTaskStatus.cancelled;

  bool get isActive =>
      this == SceneTaskStatus.queued || this == SceneTaskStatus.running;
}
