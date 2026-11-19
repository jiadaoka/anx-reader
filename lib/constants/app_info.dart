/// JiaAnx 自身的品牌与标识信息。
///
/// 与上游 Anx Reader 的标识分开维护：这里的值用于界面展示、关于页与平台配置，
/// 上游基座版本只在 [baseVersion] 里记录。
class AppInfo {
  AppInfo._();

  /// 界面展示用应用名。
  static const String appDisplayName = 'JiaAnx Reader';

  /// 关于页大标题与许可证页使用的品牌名。
  static const String appBrand = 'JiaAnx';

  /// 应用标识，与上游 com.anxcye.anx_reader 区分，保证同机安装互不覆盖。
  static const String applicationId = 'com.jia.jiaanx';

  /// 项目主页。
  static const String projectHomepage = 'https://github.com/jiadaoka/anx-reader';

  /// 上游 Anx Reader 基座版本，用于「关于 Anx Reader」对话框。
  static const String baseVersion = '1.15.0+6358';
}
