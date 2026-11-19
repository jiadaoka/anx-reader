# 剧情配图（JiaAnx）

当前分支：`feature/jiaanx-scene-image`（从 `jia-master` 新建）。
需求依据：`I:\Project\requirements\阅读器生图\JiaAnx-需求.md` v0.8、`提示词.md`、`design-2026-11-18/`。
本文件只记录实现结构与已知差异，不是需求文档；需求以依据目录为准。

## 1 代码结构

| 层 | 文件 |
| --- | --- |
| 枚举 | `lib/enums/scene_task_type.dart`、`scene_task_status.dart`、`scene_orientation.dart`、`scene_character_field.dart` |
| 模型 | `lib/models/scene_task.dart`（任务 + 历史 + 角色引用快照）、`scene_character.dart`、`scene_workflow.dart` |
| 数据库 | `lib/dao/database.dart`（v8：`tb_scene_tasks`、`tb_scene_characters`、`tb_scene_character_fragments`、`tb_scene_workflows`）、`lib/dao/scene_*.dart` |
| 服务 | `lib/service/scene_image/`：`comfyui_client.dart`、`prompt_base.dart`、`prompt_protocol.dart`、`prompt_engine.dart`、`character_resolver.dart`、`scene_context.dart`、`image_store.dart` |
| 状态 | `lib/providers/scene_tasks.dart`（`SceneTaskStore` 单例 + 提示词串行队列 + 生图轮询）、`scene_workflows.dart`、`scene_characters.dart` |
| 设置 | `lib/page/settings_page/scene_image.dart`、`scene_prompt_settings.dart`、`scene_workflow_edit.dart` |
| 角色 | `lib/page/scene_characters_page.dart`、`scene_character_detail_page.dart`、`lib/widgets/scene_image/scene_character_sheet.dart` |
| 任务 UI | `lib/widgets/scene_image/scene_task_list.dart`、`scene_task_card.dart` |
| 阅读页 | `lib/widgets/context_menu/excerpt_menu.dart`（两项菜单）、`lib/widgets/scene_image/scene_supplement_sheet.dart`、`lib/widgets/reading_page/toc_widget.dart`（第三个页签）、`lib/page/reading_page.dart`（完成提示）、`lib/page/book_player/epub_player.dart` + `assets/foliate-js/src/book.js`（前后段上下文） |

## 2 任务模型

- 两类任务共用一张表：`prompt`（提示词任务）与 `image`（生图任务），`type` 区分。
- 提示词任务：一次划词一条；历史 `history` 保存每次成功生成的提示词版本。
- 生图任务：由提示词任务发起，带 `prompt_task_id`；同一提示词（文本相同）已有生图任务时复用卡片，每次生成进 `history`，不覆盖旧图。
- 状态：`queued / running / completed / failed / cancelled`。重启后原本 `queued/running` 的任务标记为失败（原因写明应用已重启），不自动续跑、不自动重试。
- 凭据快照：提示词、补充、上下文前后段、命中角色（关键字/角色提示词/片段）、工作流 JSON 与名称、画幅、种子、来源章节与进度、时间。
- 图片落盘：应用私有目录 `scene_image/<bookId>/`，数据库只存相对路径；看图复用 `ImageViewer`（转成 base64 data URL 传入）。

## 3 提示词管线

1. 四段文本：破限 / 规范 / 任务协议 / 思考清单，均可在设置里改写；留空回落 `prompt_base.dart` 的内置文本。破限有独立开关。
2. 运行时 user 消息顺序：补充说明 → 角色档案 → 上下文段 → 划中段。
3. 角色命中：划中段 + 前后段里精确子串匹配（大小写不敏感），按划中段出现先后排序；补充说明不参与命中。
4. 上下文超量（4000 字符）时先整段丢弃前段、再丢弃后段，不切半段；缺段不阻塞，任务上记 `context_complete=false` 并在凭据里标注。
5. 模型按 `提示词.md` 返回 `<thinking>` + `{"tag","nl","negative","size"}`；宿主剥离思考、扫代码块、配平花括号取 JSON。
6. 送工作流的 `%prompt%` = `tag + "\n" + nl`（单段文本）；`%negative_prompt%` 用模型返回的 negative（为空就空串）；`size` 用于方向为「自动」时选竖/横画幅。

## 4 ComfyUI

- 地址可带/不带 scheme；测试连接走 `GET /system_stats`。
- 提交 `POST /prompt`，轮询 `GET /history/{prompt_id}`，取图 `GET /view`。
- 排队位置 `GET /queue`；取消排队中 `POST /queue {"delete":[id]}`，取消执行中 `POST /interrupt {"prompt_id":id}`（旧版 ComfyUI 会忽略 body，只中断当前任务）。
- 五个占位符：`%prompt%`、`%negative_prompt%`、`%seed%`、`%width%`、`%height%`。在 JSON 对象内递归替换；字符串恰好等于占位符时写入原始类型（数字），嵌在字符串里时写字符串；没写的占位符保持原值。
- 保存工作流不解析 JSON、不校验占位符；出图时才解析，失败给可读原因。

## 5 与依据的差异 / 已知缺口

1. **提示词输出**：需求 §3.4「单段输出、不区分 tag 与 nl」与 `提示词.md` 的 JSON 协议冲突。按需求方选择，以 `提示词.md` 为准：保留 JSON 输出并解析，再合成单段 `%prompt%`。§3.8.2「负面不在这里产出」同样按此让位：模型返回的 negative 会用于 `%negative_prompt%`。
2. **工作流选择控件**：需求写「下拉」，实现为设置行 + 底部弹层选择（功能等价）。设计稿 10 的「缺 %prompt% / 有效」状态按需求 §3.5 不做。
3. **关于页设计稿**：设计稿 09 的副标题写「基于 Anx Reader」，与需求 §3.1「不写基于」冲突；实现按需求，不写「基于」。上游关于页保留「检查更新」条目以满足「原条目不删」，但点击为静默 no-op（`EnvVar.enableCheckUpdate=false`）。
4. **来源位置**：存章名 + CFI + 阅读进度，没有单独存段序号；角色片段与任务卡都没有「跳回原文」动作。
5. **角色简介**：可手改，但没有「从片段自动提取」按钮。
6. **重试种子**：每次重试/再生图生成新种子（同种子会得到同一张图，重试就无意义）；旧的种子随历史记录保留。
7. **画幅记录**：工作流没写 `%width%/%height%` 时，任务凭据记录的是按方向选出的尺寸，实际尺寸由工作流决定，无法从 ComfyUI history 反查。
8. **zh-TW**：新增文案只补了 en / zh / zh-CN；zh-TW 及其它 locale 回落英文。
9. **旧 WebView**：只改了 `assets/foliate-js/src/book.js`，`dist/bundle.js` 未重编；Chrome <100 / 非 Apple 的旧路径拿不到前后段，任务会标上下文不足。
10. **取消执行中**：旧版 ComfyUI 的 `/interrupt` 不支持按 prompt_id，可能影响同机其它任务；新版无此问题。
11. **测试**：未新增/修改测试文件（本轮未获测试授权）。

## 6 待跑命令（由开发者执行）

```bash
# 1) 必须先生成本地化，否则 scene* getter 不存在
flutter gen-l10n

# 2) 静态检查
flutter analyze

# 3) 测试（本轮未新增测试，验证既有测试不被破坏）
flutter test

# 4) 手动冒烟
#    设置 → 更多设置 → 剧情配图：开关 / ComfyUI 连接 / 工作流新建与切换 / 提示词四段
#    阅读页划词：画这一幕（补充留空与填写各一次）/ 归入角色
#    抽屉 → 任务：排队、展开凭据、翻历史、编辑、生图、查看、重试、取消、清理
#    换书后确认任务不串书；重启后确认任务与图仍在

# 5) 若要让旧 WebView 也拿到段落上下文（会刷新其它 dist 产物）
cd assets/foliate-js && npm install && npx webpack
```

## 7 已验证 / 未验证

已构建（2026-11-20）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_ohos.ps1   # 默认 debug + x64 + --no-codesign
```

- 产物：`build/ohos/hap/entry-default-unsigned.hap`（209.6 MB，未签名）。
- HAP 内 `module.json`：`bundleName=com.jia.jiaanx`、`versionName=0.1.0`、`versionCode=1`。
- 该包面向 x64 模拟器；真机需要重新用 `-Signed` 构建并在 DevEco 配好签名。

未验证：

- `flutter analyze` 与 `flutter test` 未单独执行（鸿蒙构建已实际编译过 Dart，并跑通 `gen-l10n`）。
- Android / iOS / macOS / Windows / Linux 未构建。
- 未连真实 ComfyUI / AI 服务做端到端手测；未点过任何界面。
