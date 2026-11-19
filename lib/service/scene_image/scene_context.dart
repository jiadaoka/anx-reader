/// 一次提示词请求带的上下文上限（字符）。超过时先裁前段，再裁后段，不切半段。
const int sceneMaxContextChars = 4000;

/// 划中段始终保留；前后段超量时整段丢弃，由 [SceneContext.complete] 标注。
class SceneContext {
  const SceneContext({
    required this.before,
    required this.after,
    required this.complete,
  });

  final String before;
  final String after;
  final bool complete;
}

SceneContext trimSceneContext({
  required String excerpt,
  required String before,
  required String after,
}) {
  var keptBefore = before;
  var keptAfter = after;
  var complete = true;

  if (excerpt.length + keptBefore.length + keptAfter.length >
      sceneMaxContextChars) {
    if (keptBefore.isNotEmpty) {
      keptBefore = '';
      complete = false;
    }
  }
  if (excerpt.length + keptAfter.length > sceneMaxContextChars) {
    if (keptAfter.isNotEmpty) {
      keptAfter = '';
      complete = false;
    }
  }

  return SceneContext(
    before: keptBefore,
    after: keptAfter,
    complete: complete,
  );
}
