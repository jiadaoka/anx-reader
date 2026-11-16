# 鸿蒙（HarmonyOS）构建

本文件记录鸿蒙这条线的工具链、依赖来源和构建方式。Android / iOS / 桌面 / Web 的构建方式见 [README](../README.md)。

## 1. 工具链

| 项 | 路径 / 版本 |
| --- | --- |
| 鸿蒙版 Flutter | `I:\sdk\flutter`（3.41.9+ohos-1.0.2，Dart 3.11.5） |
| 日常版 Flutter | `I:\sdk\flutter-official`（3.47.9，Dart 3.13.7） |
| DevEco Studio | `D:\Program Files\Huawei\DevEco Studio`（26.0.0.865） |
| HarmonyOS SDK | `D:\Program Files\Huawei\DevEco Studio\sdk`（API 26） |
| hdc | `D:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe` |
| pub 缓存 | `I:\pub_cache` |

两个 SDK 的 engine 产物源不同，**不要共用一个终端**：

```cmd
call I:\sdk\use-ohos.cmd     :: 鸿蒙构建
call I:\sdk\use-daily.cmd    :: Android / Windows / Web
```

用官方 SDK 跑 `flutter pub get` 会把 `.flutter-plugins-dependencies` 里的 ohos 插件信息清掉，
之后打出来的包里没有任何 ohos 插件注册。

## 2. 构建

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_ohos.ps1
```

参数：`-Mode debug|release`（默认 debug）、`-Arch x64|arm64`（默认 x64）、`-Signed`（产物要装到设备时加）。

脚本做的事：

1. 摆好 `FLUTTER_ROOT` / `PUB_CACHE` / `HOS_SDK_HOME` / `PATH`（不依赖终端里是哪个 flutter）；
2. 调 `scripts/setup_ohos.ps1` 补齐 `ohos/build-profile.json5`；
3. 调 `scripts/ohos_patch_target_platform.py apply` 给第三方包补 `TargetPlatform.ohos`；
4. `flutter build hap`；
5. **无论成败**都 `restore` 第三方包，避免影响日常 Android / 桌面构建。

产物：`build/ohos/hap/entry-default-unsigned.hap`（未签名时），或
`ohos/entry/build/default/outputs/default/entry-default-signed.hap`（配好签名后）。

## 3. 为什么需要第三方包补丁

鸿蒙版 Flutter 给 `TargetPlatform` 加了 `ohos` 取值，Dart 的 switch 穷尽性检查会让
没写这个分支的第三方包直接编译失败：

```
flex_color_scheme、flutter_math_fork、mongol
```

`scripts/ohos_patch_target_platform.py` 会在每个 switch 的第一个 case 前插一行
`case TargetPlatform.ohos:`（共用那个分支体），所以 ohos 走 android 的行为。
补丁改的是 pub 缓存里的源文件，备份在 `build/ohos/target-platform-backup/`，`restore` 可还原。

这是临时债：等上游包自己处理 `TargetPlatform.ohos`，删掉脚本里的 `PACKAGES` 即可。

另外 `in_app_purchase_android` 钉在 `^0.4.0`：0.5.x 要求 Dart 3.12，而鸿蒙 SDK 是 3.11.5。
Android / Play 的构建走 develop 分支，同样用 0.5.x。

## 4. 依赖来源

鸿蒙侧没有上游实现，下面这些包在本分支换成了带 `ohos` 平台的来源：

| 包 | 来源 |
| --- | --- |
| `file_picker` | 本地 shim `third_party/file_picker` → gitcode `fluttertpc_file_picker` 的 `file_picker_ohos` 10.3.8 |
| `path_provider` | gitcode `openharmony-tpc/flutter_packages`，分支 `br_path_provider-v2.1.5_ohos` |
| `shared_preferences` | 同一仓库，分支 `br_shared_preferences-v2.5.4_ohos` |
| `sqflite` | gitcode `Anxcye/flutter_sqflite`，分支 `br_v2.4.1_ohos` |
| `flutter_inappwebview` | gitcode `Anxcye/flutter_inappwebview`，分支 `br_v6.1.5_ohos` |
| `permission_handler` | gitcode `openharmony-sig/flutter_permission_handler`，分支 `br_permission_handler_v11.3.1_ohos` |
| `url_launcher` | gitcode `openharmony-tpc/flutter_packages`，分支 `br_url_launcher-v6.3.2_ohos` |
| `fluttertoast` | gitcode `openharmony-sig/flutter_fluttertoast`，分支 `br_8.2.8_ohos` |
| `flutter_file_dialog` | vendor `third_party/flutter_file_dialog`（Anxcye fork 3.0.3；上游版本没有 ohos） |
| `audio_service` | gitcode `openharmony-sig/fluttertpc_audio_service`，分支 `br_v0.18.18_ohos` |
| `audio_session` | gitcode `CPF-Flutter/flutter_audio_session`，分支 `br_v0.2.2_ohos`（`audio_service` 自己就钉这个 ref） |
| `device_info_plus` | gitcode `openharmony-sig/flutter_plus_plugins`，分支 `br_device_info_plus_v11.4.0_ohos` |
| `connectivity_plus` | 同一仓库，分支 `br_connectivity_plus-v6.1.0_ohos` |
| `battery_plus` | 同一仓库，分支 `br_battery_plus-v6.1.0_ohos` |
| `share_plus` | 同一仓库，分支 `br_share_plus-v12.0.1_ohos` |
| `wakelock_plus` | gitcode `openharmony-sig/fluttertpc_wakelock_plus`，分支 `br_v1.3.2_ohos` |
| `intl` | 区间约束 `>=0.20.2 <0.20.4`，兼容两套 SDK 的 `flutter_localizations` |

几个约束：

- `dependency_overrides` 里必须重复声明 `path_provider` / `shared_preferences` / `sqflite` / `file_picker`：
  其它包仍按 hosted 约束要求它们，不声明 override 时 pub 不会采用 git 来源。
- `sqflite_ohos`、`sqflite_common`、`sqflite_platform_interface` 必须和 `sqflite` 同源，
  否则 pub 报 "from git is incompatible with from hosted"。
- `shared_preferences_ohos`、`sqflite_ohos` 作为直接依赖列出：应用不 import 它们，但只有进依赖图，
  flutter 工具才会把它们写进 `GeneratedPluginRegistrant.ets`。
- `file_picker` 的 fork 把包改名为 `file_picker_ohos`，`third_party/file_picker` 只做一层转出，
  所以 `lib/` 里的 import 不用改。
- pub 拉 `flutter_packages` 会遇到超长路径，需要 `git config --global core.longpaths true`。
- `flutter_audio_session` 的 fork 里 `example/` 用了 Git LFS，远端缺对象会让 checkout 失败；
  `scripts/build_ohos.ps1` 里设了 `GIT_LFS_SKIP_SMUDGE=1` 绕过（构建不需要 example）。

当前注册进鸿蒙的插件（`ohos/entry/src/main/ets/plugins/GeneratedPluginRegistrant.ets`）：

```
audio_service, audio_session, battery_plus, connectivity_plus, device_info_plus,
file_picker_ohos, flutter_file_dialog, flutter_inappwebview_ohos, flutter_tts,
fluttertoast, path_provider_ohos, permission_handler_ohos, saver_gallery,
share_plus, shared_preferences_ohos, sqflite_ohos, url_launcher_ohos, wakelock_plus
```

`pubspec.lock` 是鸿蒙 SDK 解析出来的结果（`intl 0.20.2` 等）。切回日常 SDK 构建前
需要重新 `flutter pub get`，锁文件会再变一次——这是两套 SDK 共用一份 lock 的固有现象。

## 5. 还没接的插件

| 包 | 影响 | 原因 |
| --- | --- | --- |
| `audioplayers` | 在线 TTS 音频播放（`online_tts.dart` 一处） | 6.5.1 的 fork 是 pub workspace（`resolution: workspace`），不能直接当 path 依赖用；要用得 vendor 整套 packages |
| `vibration`、`haptic_feedback` | 震动手感 | 无 ohos 实现，可降级 |
| `share_handler` | 接收其他应用分享进来的文件 | 官方用 `receive_sharing_intent` 顶替，尚未接 |
| 排除 | — | `desktop_drop`、`window_manager`、`screen_retriever`、`webview_cef`、`sqlite3_flutter_libs`、`in_app_purchase*` 是桌面 / 仅 Android / 商店能力 |

注意：`flutter_inappwebview` 的 6.1.5 fork 没有可用的 `flutter_inappwebview_windows` 平台包，
构建时会有一条 warning，Windows 注册表里也会少它（应用在 Windows 走 `webview_cef`）。

`lib/main.dart` 的 `AudioService.init` 包了 try/catch：平台上没有 audio_service 时会退化成
`_UnavailableAudioHandler`（TTS 静默不可用），保证应用能启动。鸿蒙现在已有实现，走的是真实分支。

## 6. 装机与调试

**模拟器不校验签名**：`hdc install` 可以直接装 `entry-default-unsigned.hap`。
真机不行，必须走下面的签名流程：

1. DevEco 里打开 `ohos` 目录（不是仓库根目录）；
2. File → Project Structure → Signing Configs → 勾选 Automatically generate signature；
3. 回到命令行：`scripts\build_ohos.ps1 -Arch arm64 -Signed`；
4. `hdc install -r ohos\entry\build\default\outputs\default\entry-default-signed.hap`。

模拟器是 x86_64 镜像（`I:\sdk\system-image\HarmonyOS-7.0.0\phone_all_x86`），真机用 `arm64`。

启动模拟器（无窗口）：

```powershell
& 'D:\Program Files\Huawei\DevEco Studio\tools\emulator\Emulator.exe' -start 'Mate 90 Pro' `
  -instancePath 'D:\huawei' -imageRoot 'I:\sdk' -noWindow
# 等 hdc list targets 里 127.0.0.1:5555 从 Offline 变 Connected
```

界面操作可以脚本化：`hdc shell uitest uiInput click <x> <y>` + `hdc shell snapshot_display -f /data/local/tmp/x.jpeg`。

## 7. 验证记录

2026-11-16，`Mate 90 Pro`（HarmonyOS 7.0.0 / API 26 / x86_64）实测通过：

| 步骤 | 结果 |
| --- | --- |
| `hdc install` 未签名包 | ✅ 装机成功（模拟器不校验签名） |
| 冷启动 | ✅ 引导页 → 书架 |
| 系统文件选择器 | ✅ 打开、可选文件、返回应用 |
| 导入书籍 | ✅ 提示"导入成功"，书架出现该书 |
| 打开阅读 | ✅ WebView 渲染出正文与章节标题 |
| TTS 平台通道 | ✅ `audio_service` / `audio_session` 通道通信，系统 `AVSession` 创建成功 |
| 电量显示 | ✅ 阅读页状态栏显示 100%（`battery_plus` ohos） |
| 阅读常亮 | ✅ `wakelock_plus` 的 pigeon 通道被调用 |

说明：P0 刚接入时 `AudioService.init` 会抛 `MissingPluginException` 导致白屏，先加兜底才走通；
P2 接入 `audio_service` 后走的是真实分支，兜底只作防御。


## 8. 排错

| 现象 | 多半是 | 处理 |
| --- | --- | --- |
| `Could not find a command named "hap"` | 当前终端是官方 SDK | 用 `scripts\build_ohos.ps1`，或 `call I:\sdk\use-ohos.cmd` |
| `not exhaustively matched ... TargetPlatform` | 第三方包缺 ohos 分支 | 确认补丁脚本执行过（`python scripts\ohos_patch_target_platform.py status`） |
| `language version 3.12 ... too high` | 某个包要求 Dart 3.12 | 钉回兼容版本（参考 `in_app_purchase_android`） |
| 启动白屏 | 插件没注册（`shared_preferences` / `path_provider` / `audio_service`） | 看 `GeneratedPluginRegistrant.ets`；`hilog -x -P <pid> -e 'MissingPlugin'` |
| 点"导入"没反应 | `file_picker` 通道没人应答 | `hdc shell hilog` 搜 `filepicker` |
| `hvigorw` 退出 1 | 真正的错误在 hvigor 日志 | `ohos/.hvigor/outputs/build-logs/build.log` 搜 `[ERROR]` |
| 装上闪退 | `libflutter.so` 架构与 `-Arch` 不一致 | 解包看 `libs/<abi>/libflutter.so` |
