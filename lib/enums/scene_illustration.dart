/// 插图最近一次插入的来源：生图完成自动插入，或在任务卡手动插入。
enum SceneIllustrationMode {
  auto('auto'),
  manual('manual');

  const SceneIllustrationMode(this.code);

  final String code;

  static SceneIllustrationMode fromCode(String code) {
    return SceneIllustrationMode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SceneIllustrationMode.auto,
    );
  }
}

/// 锚点状态。失效后不再显示，也不再自动重试定位。
enum SceneAnchorStatus {
  valid('valid'),
  invalid('invalid');

  const SceneAnchorStatus(this.code);

  final String code;

  static SceneAnchorStatus fromCode(String code) {
    return SceneAnchorStatus.values.firstWhere(
      (e) => e.code == code,
      orElse: () => SceneAnchorStatus.valid,
    );
  }
}
