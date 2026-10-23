# 七项目配置差异对比

> 对比时间：2026-10-23（7 项目复查；7 个仓库工作区均 clean，HEAD 与 tag 已推送）
> 对比范围：pubspec 依赖、Android 构建配置与签名、analysis_options（lint）、
> CI 工作流（GitHub + Gitea）、仓库卫生与目录结构、代码层共享组件
> 项目清单：`flutter-bilibili-downloader-d4-qwen-code`（下称 bilibili）、
> `flutter-gomoku`（gomoku）、`flutter-music`（music）、`flutter-racing`（racing）、
> `flutter-snake`（snake）、`flutter-tank-battle`（tank）、`flutter-tetris`（tetris）
>
> 上一版（2026-10-19 / 20，4 项目）的结论仍然成立；遗留的 2 个可选项
> （music 的 windows/ 策略、bilibili 的 gradle.properties 注释）仍未处理。
> 本次新增 gomoku / racing / tank，并补上仓库卫生与代码层对比。

## 0. 结论速览

1. **工程模板层已统一**：工具链、基础依赖、lint、签名、双流水线骨架、
   versions.md 机制在 7 个项目上逐项一致。
2. **代码层两项已统一**：`lib/services/log_service.dart` 7 份逐字节一致；
   设置页日志查看 UI（弹窗 + 复制全部 + 日志目录 tile）7 份齐备。
3. **剩余真分叉 9 处（A 类）**，集中在 gomoku / racing / tank 三个较新的仓库。
   其中只有 A2（日志目录落点）与 A9（FileSystemService）涉及运行行为，
   其余为仓库卫生与构建配置。
4. 其余差异属于业务差异（依赖、包名、assets、权限、横屏）或装饰差异，
   不建议强行统一。

## 1. 项目概览

| 项                            | bilibili                | gomoku             | music             | racing             | snake             | tank                    | tetris             |
|-------------------------------|-------------------------|--------------------|-------------------|--------------------|-------------------|-------------------------|--------------------|
| 应用类型                      | Bilibili 下载器         | 五子棋             | 本地音乐播放器    | 赛车游戏           | 贪吃蛇            | 坦克大战                | 俄罗斯方块         |
| 版本号（pubspec）             | 0.4.33                  | 0.3.8              | 0.3.49            | 0.1.2              | 0.3.4             | 0.3.2                   | 0.6.3              |
| applicationId / namespace     | com.bilibili.downloader | com.flutter.gomoku | com.flutter.music | com.flutter.racing | com.flutter.snake | com.flutter.tank_battle | com.flutter.tetris |
| rootProject.name              | bilibili_downloader     | flutter_gomoku     | flutter_music     | flutter_racing     | flutter_snake     | flutter_tank_battle     | flutter_tetris     |
| 正式 keystore（android/app/） | bilibili-downloader.jks | flutter-gomoku.jks | flutter-music.jks | flutter-racing.jks | flutter-snake.jks | flutter-tank-battle.jks | flutter-tetris.jks |
| 业务依赖                      | 见 3.2                  | 仅 path            | 见 3.2            | audioplayers       | audioplayers      | audioplayers            | audioplayers       |
| assets/                       | 无                      | 无                 | 无                | audio/             | 无                | audio/                  | 无                 |
| lib Dart 文件数               | 29                      | 21                 | 30                | 30                 | 17                | 27                      | 28                 |
| test 文件数                   | 3                       | 9                  | 10                | 11                 | 5                 | 7                       | 14                 |

## 2. Dart / Flutter 环境（完全一致）

| 配置            | 7 项目统一值                                                         |
|-----------------|----------------------------------------------------------------------|
| Dart SDK 约束   | `>=3.13.5 <4.0.0`                                                    |
| CI Flutter 版本 | `3.47.7`（GitHub workflow env `FLUTTER_VERSION`；Gitea runner 预装） |
| CI JDK          | Temurin 21（GitHub workflow env `JAVA_VERSION`；Gitea runner 预装）  |

## 3. pubspec.yaml 依赖对比

### 3.1 共有依赖（已全部对齐）

| 依赖                  | 7 项目统一值 |
|-----------------------|--------------|
| provider              | 6.1.5+1      |
| shared_preferences    | 2.5.6        |
| path_provider         | 2.1.6        |
| window_manager        | 0.5.2        |
| flutter_localizations | sdk: flutter |
| flutter_lints（dev）  | 6.0.0        |

注：`path` 在 bilibili 以外的 6 个项目为直接依赖（1.9.1），bilibili 未直接声明。

### 3.2 各项目独有依赖（业务决定，不属于基础依赖）

| 项目     | 独有依赖                                                                                                                                                            |
|----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| bilibili | dio 5.11.1、intl 0.20.3、crypto 3.0.7、flutter_local_notifications 22.3.2、url_launcher 6.3.3、ffmpeg_kit_extended_flutter 0.6.2（三平台原生库走 gh-proxy）         |
| gomoku   | 无（仅 path）                                                                                                                                                       |
| music    | just_audio 0.10.6、just_audio_windows 0.2.3、audio_service 0.18.19、audio_session 2.0.4、audio_metadata_reader 1.8.1、file_picker 13.1.0、permission_handler 13.0.2 |
| racing   | audioplayers 6.8.1                                                                                                                                                  |
| snake    | audioplayers 6.8.1                                                                                                                                                  |
| tank     | audioplayers 6.8.1                                                                                                                                                  |
| tetris   | audioplayers 6.8.1                                                                                                                                                  |

注：music 的音频栈版本已高于上一版 diff.md 记录，以本表为准。

## 4. Android 构建配置

### 4.1 完全一致

| 配置                            | 7 项目统一值                                                                     |
|---------------------------------|----------------------------------------------------------------------------------|
| AGP                             | 9.4.1（settings.gradle 插件声明）                                                |
| Kotlin                          | 2.4.21（插件 + kotlin-stdlib）                                                   |
| Gradle                          | 9.8.2-all（华为云镜像 distributionUrl）                                          |
| compileSdk / targetSdk / minSdk | 37 / 37 / 35                                                                     |
| NDK                             | 30.0.16248370                                                                    |
| Java 兼容性                     | VERSION_21 + jvmTarget 21                                                        |
| coreLibraryDesugaring           | 2.1.5（启用）                                                                    |
| ABI                             | 仅 arm64-v8a                                                                     |
| R8 / 资源收缩                   | `minifyEnabled false` + `shrinkResources false`（全关）                          |
| gradle.properties               | -Xmx4G、useAndroidX、newDsl=false、builtInKotlin=false、kotlin.incremental=false |
| Maven 镜像机制                  | `USE_ALIYUN_MAVEN` 条件启用阿里云镜像                                            |

以下文件逐字一致：`analysis_options.yaml`（7 份）、
`android/gradle/wrapper/gradle-wrapper.properties`（7 份）、
`android/gradle/init-aliyun-mirror.gradle`（7 份）。
`android/build.gradle` 有两个版本（见 A5），`.build/query_all_versions.py` 也有两代（见 A4）。

### 4.2 签名策略（已统一）

7 个项目机制一致：`android/key.properties` + `android/app/<应用名>.jks`，
debug 与 release 均指向 `signingConfigs.release`，签名材料随仓库分发，
`.gitignore` 无签名相关忽略项，CI 直接出包。

### 4.3 剩余差异（应用标识与装饰为主）

| 差异点                                       | 现状                                                                                                                          |
|----------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
| namespace / applicationId / rootProject.name | 各项目自有标识（正常差异）                                                                                                    |
| gradle.properties                            | bilibili 多两行注释且带末尾换行，其余 6 份逐字一致                                                                            |
| flutterVersionName 兜底                      | gomoku 为 `0.1.3`，其余 6 个为 `0.1.0`                                                                                        |
| Maven 镜像源                                 | bilibili/gomoku/music/snake/tetris 为阿里云 3 项、`mavenCentral()` 在前；racing/tank 另有腾讯云与华为云 4 项、`google()` 在前 |
| signingConfigs 注释                          | bilibili / racing / tank 三种措辞（配置项完全一致）                                                                           |

### 4.4 应用清单差异（部分属业务决定）

| 项                | bilibili                | gomoku | music                             | racing           | snake  | tank             | tetris           |
|-------------------|-------------------------|--------|-----------------------------------|------------------|--------|------------------|------------------|
| 应用名来源        | 硬编码                  | 硬编码 | @string/app_name                  | @string/app_name | 硬编码 | @string/app_name | @string/app_name |
| strings.xml       | 有                      | 无     | 有                                | 有               | 无     | 有               | 有               |
| INTERNET 权限     | 有                      | 有     | 无                                | 无               | 无     | 无               | 无               |
| 其他组件/权限     | FileProvider、cleartext | —      | 媒体/通知/前台服务 + AudioService | —                | —      | —                | —                |
| screenOrientation | —                       | —      | —                                 | landscape        | —      | —                | —                |

## 5. analysis_options.yaml（lint）

7 份逐字一致（md5 `0b5e2c78`）：`include: package:flutter_lints/flutter.yaml`
之上 13 条规则配置，`avoid_print` 显式关闭，其余启用。

## 6. CI 工作流对比

7 个项目均为双轨制：`.github/workflows/build.yml` + `.gitea/workflows/build.yml`。
以下内容完全一致：

- 触发：push tag `v*` + workflow_dispatch；`concurrency` 按 sha 分组并取消旧构建
- 命名：workflow / run-name / job / step 全部中文 + emoji
- 版本号：从 `pubspec.yaml` 解析，tag 触发时优先取 tag 中的版本
- 流水线：metadata → test（`flutter analyze --no-fatal-infos --no-fatal-warnings`
    + `flutter test`）→ build-android ∥ build-windows → release
- Windows 构建：复制到短路径 `C:\w`（`cygpath` + `cp -a`）→ `pub get`
  → `flutter create --platforms=windows` → 构建
- ZIP 打包：pwsh `Compress-Archive`
- 产物命名：`{仓库名}-{版本}-android-aarch64.apk` / `-windows-x86_64.zip`
- GitHub 产物保留 1 天；prerelease 自动识别 `-rc` / `-beta`
- changelog 排除 docs、.github、.gitea

### 6.1 项目专属差异

| 差异点                         | bilibili | gomoku | music | racing | snake | tank | tetris |
|--------------------------------|----------|--------|-------|--------|-------|------|--------|
| run-name emoji                 | 📺       | ♟️     | 🎵    | 🏁     | 🐍    | 🪖   | 🎮     |
| CMP0091 步骤                   | 无       | 无     | 无    | 有     | 有    | 有   | 有     |
| GitHub changelog 排除 `.gitea` | 有       | **缺** | 有    | 有     | 有    | 有   | 有     |

CMP0091 与依赖严格对应：使用 `audioplayers 6.8.1` 的 racing / snake / tank /
tetris 需要该步骤，其余 3 个不需要。GitHub `windows-latest` 已指向 VS 2026
镜像，`audioplayers_windows` 4.4.1 要求 CMP0091 NEW；sed 在
`cmake_minimum_required` 行后插入策略并用 grep 校验，模板失配时显式失败。

### 6.2 GitHub 与 Gitea 双轨之间的固有差异

| 维度     | GitHub Actions                                                    | Gitea Actions                                                                                                                           |
|----------|-------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| runner   | ubuntu-latest / windows-latest                                    | ubuntu-flutter / windows-flutter（自建，预装 Flutter/JDK）                                                                              |
| 环境准备 | subosito/flutter-action@v2（3.47.7）+ setup-java@v5（temurin 21） | 无 setup 步骤；构建前做环境诊断（flutter doctor、storage.flutter-io.cn 连通性）并部署 `init-aliyun-mirror.gradle` 到 `~/.gradle/init.d` |
| 超时     | 无特殊设置                                                        | build job `timeout-minutes: 30`                                                                                                         |
| 产物传递 | upload-artifact@v7 / download-artifact@v8（merge-multiple）       | gitea-upload-artifact@v4 / gitea-download-artifact@v8（release 按名逐个下载）                                                           |
| release  | softprops/action-gh-release@v3                                    | `GITEA_TOKEN` + curl 直调 Gitea API                                                                                                     |

## 7. 仓库卫生与工程结构

### 7.1 `.metadata` 与 `.gitignore`（三套模板）

| 项                | bilibili | gomoku | music          | racing | snake | tank   | tetris |
|-------------------|----------|--------|----------------|--------|-------|--------|--------|
| `.metadata` 入库  | 否       | **是** | 否             | **是** | 否    | **是** | 否     |
| `.gitignore` 模板 | A        | B      | C              | B      | C     | B      | C      |
| `windows/` 入库   | 无       | 无     | CMakeLists.txt | 无     | 无    | 无     | 无     |
| 版本脚本          | 旧       | 旧     | 旧             | 新     | 旧    | 新     | 旧     |
| prompt.md         | 有       | 有     | 有             | 无     | 有    | 有     | 有     |

模板定义：

- **A（bilibili）**：忽略 `.metadata`；windows 子目录细粒度；额外忽略
  `downloads/`、`*.mp4`；不列 `.flutter-plugins`。
- **B（gomoku / racing / tank）**：忽略 `.flutter-plugins`， **不忽略 `.metadata`**；
  整目录忽略 `windows/`、`macos/`、`ios/`、`linux/`；racing/tank 另忽略 `tools/`。
- **C（music / snake / tetris）**：忽略 `.metadata` 与 `.flutter-plugins`；
  整目录忽略 `windows/` 等。

`.metadata` 入库的 3 个项目正是上一轮清理未覆盖的新仓库；bilibili 等 4 个均按
「删除 + 忽略」处理。

### 7.2 windows/ 策略

只有 music 入库 `windows/CMakeLists.txt`，其余 6 个完全交给 CI 的
`flutter create` 生成。该文件内仍保留
`_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`——上一版已判定该协程
静默补丁在 `audioplayers 6.8.1` 后作废，music 又不使用 audioplayers，属历史残留。

### 7.3 `.build/query_all_versions.py` 两代并存

- racing / tank：新版，比旧版多两处守卫——工作流文件不存在时跳过；
  单流水线时把文案改成「GitHub Actions 流水线」。
- 其余 5 个：旧版。新版是向后兼容超集，缺少的只是健壮性。

7 份 `versions.md` 结构一致（94~101 行），版本表与 `pubspec.yaml`、
`lib/utils/constants.dart` 均同步。

### 7.4 文档齐套性

- `plan.md`：7 个均有。
- `prompt.md`：racing 缺。
- `diff.md`：仅 bilibili（本文档）。

## 8. 代码层共享组件

### 8.1 LogService（已统一）

7 份 `lib/services/log_service.dart` 逐字节一致（md5 `b709171b`）：
早期缓冲 500 + 内存缓冲 2000 + 目录不可用降级内存模式；7 天 mtime 清理、
5MB 轮转 `app_YYYYMMDD_N.log`；`init({required logRoot, clock?})` 注入目录。

### 8.2 设置页日志 UI（已统一）

7 份设置页均有「日志目录」tile（复制路径 + 桌面端打开目录）与「查看日志」
弹窗（刷新 / 复制全部 / 关闭，200 行 monospace `SelectableText`）；
刷新按钮使用 `StatefulBuilder` 重建，修复了父级 `setState` 不刷新弹窗的问题。
bilibili 与 tetris 的「日志目录」字符串各出现 2 次（其余 3 次），tetris 的
`openDirectory` 还是设置页内本地实现；两者属实现位置差异，不影响功能与外观。

### 8.3 FileSystemService 与日志落点（A9 / A2）

| 项目     | 行数 | 公开方法                                                                                      |
|----------|------|-----------------------------------------------------------------------------------------------|
| bilibili | 257  | 下载根、日志根、revealInFileManager、openDirectory、openWithSystemPlayer、mergeAv、probeMedia |
| gomoku   | 52   | reset、getLogRoot、openDirectory                                                              |
| music    | 93   | getUserRoot、getLogRoot、openDirectory                                                        |
| racing   | 54   | getLogRoot、openDirectory                                                                     |
| snake    | 62   | getUserRoot、getLogRoot、openDirectory                                                        |
| tank     | 52   | getLogRoot、openDirectory                                                                     |
| tetris   | —    | 无 FSS，`main.dart` 内联 `_logRoot`                                                           |

日志目录 5 种落点：

| 项目     | 日志目录                                              |
|----------|-------------------------------------------------------|
| bilibili | `<Documents 或 external>/logs`（无应用子目录）        |
| gomoku   | `<ApplicationSupport>/logs`（Android 为应用内部目录） |
| music    | `<Documents 或 external>/FlutterMusic/logs`           |
| racing   | `<Documents 或 external>/FlutterRacing/logs`          |
| snake    | `<Documents 或 external>/FlutterSnake/logs`           |
| tank     | `<Documents 或 external>/TankBattle/logs`             |
| tetris   | `<Documents>/FlutterTetris/logs`                      |

影响：bilibili 在 Windows 会写公共 `Documents\logs`；gomoku 在 Android
落在应用内部目录，文件管理器不可见，与设置页「日志目录」入口的语义不符。

### 8.4 目录结构差异

| 项目     | 特有目录                                       | lib Dart 数 | test 文件数 |
|----------|------------------------------------------------|-------------|-------------|
| bilibili | 无 widgets/；主题文件为 `china_app_theme.dart` | 29          | 3           |
| gomoku   | `ai/`                                          | 21          | 9           |
| music    | 无                                             | 30          | 10          |
| racing   | `engine/`                                      | 30          | 11          |
| snake    | 无                                             | 17          | 5           |
| tank     | `engine/`                                      | 27          | 7           |
| tetris   | 无                                             | 28          | 14          |

bilibili 的主题文件名与其余 6 个（`app_theme.dart`）不同，属命名差异。

## 9. 差异分级

### A 类：建议统一

| 编号 | 差异                                 | 位置                                      | 影响                              | 建议                            |
|------|--------------------------------------|-------------------------------------------|-----------------------------------|---------------------------------|
| A1   | `.metadata` 入库 + `.gitignore` 三套 | gomoku / racing / tank                    | 仓库约定不一致                    | 取消入库并统一模板              |
| A2   | 日志目录 5 种落点                    | FSS / main.dart                           | 路径不可见或跨应用冲突            | 统一 `<用户根>/<应用目录>/logs` |
| A3   | GitHub changelog 缺 `.gitea` 排除    | gomoku workflow                           | release notes 混入配置提交        | 补排除                          |
| A4   | 版本脚本两代                         | `.build/query_all_versions.py`            | 缺少工作流时读取失败              | 回填 racing/tank 版             |
| A5   | Maven 镜像两套                       | `android/build.gradle`、`settings.gradle` | 拉取稳定性与顺序不一致            | 以 racing/tank 为基线           |
| A6   | 兜底版本 `0.1.3`                     | gomoku `app/build.gradle`                 | `local.properties` 缺失时版本错误 | 改 `0.1.0`                      |
| A7   | 唯一入库 windows 工程文件 + 旧宏     | music `windows/CMakeLists.txt`            | 与其余 6 个策略相反               | 删除或清理                      |
| A8   | 应用名资源化不一致                   | Manifest / strings.xml                    | 改名与多语言成本                  | 统一 `@string/app_name`         |
| A9   | FSS 6 份实现 + tetris 缺失           | `lib/services/`                           | 公共内核重复维护                  | 收敛最小契约                    |

### B 类：装饰或卫生，可顺手

- bilibili `gradle.properties` 的两行注释与末尾换行。
- `signingConfigs` 注释的三种措辞。
- bilibili 主题文件名 `china_app_theme.dart`。
- racing 缺 `prompt.md`。
- `.gitignore` 中 `downloads/`、`*.mp4`、`tools/` 的取舍。
- README 结构与长度（业务文档，不建议统一）。

### C 类：有意保留

- 业务依赖、applicationId / namespace / rootProject.name。
- CI run-name emoji。
- CMP0091 步骤（与 audioplayers 依赖严格对应）。
- racing 横屏、music 的权限与 AudioService、bilibili 的
  INTERNET / FileProvider / cleartext。
- `assets/audio/`。
- 测试数量差异（3~14 个文件，反映业务复杂度）。
- 平台目录：7 个项目均未入库完整 `windows/` 工程（music 仅一个 CMakeLists），
  iOS / macOS / Linux / web 全部缺失。

## 10. 演进路线

### P0 仓库卫生（零功能风险，逐仓库一个提交）

1. gomoku / racing / tank：`git rm --cached .metadata`，`.gitignore` 统一为
   一套模板（以 C 为基础，按需保留 A 的 `downloads/`、`*.mp4`）。
2. gomoku：GitHub workflow 补 `":(exclude).gitea"`。
3. gomoku：`flutterVersionName` 兜底改 `0.1.0`。
4. 5 个旧仓库回填 racing/tank 版 `query_all_versions.py`，随后重跑脚本刷新
   `versions.md`。

### P1 构建配置对齐

5. 以 racing/tank 的镜像源为基线，回填其余 5 个，保留 `USE_ALIYUN_MAVEN`。
6. gomoku / snake 补 `strings.xml`，bilibili 改用 `@string/app_name`。
7. music 的 `windows/CMakeLists.txt` 做决策：删除并交给 CI（与 6 个项目一致），
   或保留并移除旧协程宏。
8. 可选：bilibili gradle.properties 注释、签名注释措辞、主题文件改名。

### P2 代码层最小契约

9. 约定日志目录为 `<用户可见根>/<应用目录>/logs>`：先修 bilibili（加应用
   子目录）与 gomoku（改 external / Documents），其余 4 个保持。
10. `FileSystemService` 收敛为「单例 + `getLogRoot` + `openDirectory`」，
    项目特有方法保留；tetris 补齐 FSS 或至少让 `_logRoot` 走同一约定。
11. `log_service_test.dart` 已一致，无需改动；如需可补 FSS 测试。

### P3 版本演进

12. 工具链保持一致升级节奏：先 bilibili + racing 验证，通过后回填其余 5 个。
13. 每次改动先用 `workflow_dispatch` 触发双轨构建验证，再打 tag。

## 11. 差异之外的提醒

- `audioplayers 6.8.1`（racing / snake / tank / tetris）：workflow 中的
  CMP0091 步骤是上游对 VS 2026 的明确要求，升级前先重查其
  `audioplayers_windows` 的 README/CMake 要求，不要顺手删除。
- `ffmpeg_kit_extended_flutter`（bilibili）原生库三平台走 gh-proxy，
  是该网络环境下的特例配置。
- 7 个项目 CI 的 Flutter / JDK / AGP / Kotlin / Gradle 完全同版本，
  工具链层面不存在分叉；后续升级建议同步推进。
- 本机 `flutter` / `dart` CLI 不可用，本文档所有结论来自静态文件核对，
  未运行 `flutter analyze` / `flutter test`；P0 / P1 改动需依赖 CI 双轨验证。

## 12. 提交索引（备查）

**第一轮统一（2026-10-17 ~ 10-19 上午，均已提交）**

| 项目                 | 相关提交                                                                                                                               |
|----------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| bilibili（模板先行） | 2890516 workflow 中文名、d1d786e C:\w 短路径、b1af1de bash cp -a、5e33bec 关 R8、58d0fb6 版本脚本通用化、bb55eec changelog 排除 .gitea |
| music                | 737973f 依赖升级、6deab1e 统一签名、f2a5881 Windows 短路径 + 日志统一、2253f36 补齐 lint、c1dd03a versions.md、a72511b 签名材料入库    |
| snake                | 847851e 包名改 com.flutter.snake + 统一签名、19b8845 双流水线优化避长路径、9b4c2a6 依赖升级、0c2f16f versions.md、b7c516d 签名密钥入库 |
| tetris               | c54f066 统一长期签名、14b4c07 依赖升级、0547163 双流水线 Windows 与中文日志、c942031 versions.md、c1cccc8 签名材料入库                 |

**第二轮清理（2026-10-19 下午，已包含在后续发布提交中）**

- bilibili：移除 ffmpeg-kit 日志导出步骤、兜底版本 0.1.0、`.gitignore`
  增加 `.metadata`。
- music / snake / tetris：删除 `.metadata` 与残留 `debug.keystore`；
  snake 迁移 Kotlin MainActivity；snake / tetris 升级 audioplayers 6.8.1
  并改用 CMP0091 步骤。

**当前 HEAD（2026-10-23 核对，均已推送 tag）**

| 项目     | HEAD    | tag     |
|----------|---------|---------|
| bilibili | 5bcad72 | v0.4.33 |
| gomoku   | 17ea43a | v0.3.8  |
| music    | 638d1fc | v0.3.49 |
| racing   | 9e0f970 | v0.1.2  |
| snake    | c1a69b2 | v0.3.4  |
| tank     | 1565803 | v0.3.2  |
| tetris   | 20986f0 | v0.6.3  |

**本次更新（2026-10-23）**：仅 `diff.md`（本文档），尚未提交。
