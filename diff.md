# 七项目配置差异对比

> 对比时间：2026-10-23（第二轮复查 + A1/A9 收尾；复核时 7 个仓库工作区均 clean，
> 本轮新增提交尚未推送）
> 对比范围：pubspec 依赖、Android 构建配置与签名、analysis_options（lint）、
> CI 工作流（GitHub + Gitea）、仓库卫生与目录结构、代码层共享组件
> 项目清单：`flutter-bilibili-downloader-d4-qwen-code`（下称 bilibili）、
> `flutter-gomoku`（gomoku）、`flutter-music`（music）、`flutter-racing`（racing）、
> `flutter-snake`（snake）、`flutter-tank-battle`（tank）、`flutter-tetris`（tetris）
>
> 本版是 A 类整改后的复采样（上一版快照为 bilibili `8a3f555`）。上一版列出的
> 9 项 A 类差异已全部关闭：`.metadata` / `.gitignore` 在 A1 收尾中统一，
> FileSystemService 在 A9 收尾中收敛为同一最小契约。

## 0. 结论速览

1. **工程模板层已完全统一**：工具链、基础依赖、lint、签名、Maven 镜像、
   Gradle/Kotlin 资源限制、版本脚本在 7 个项目上逐项一致；同一轨道的 7 份
   工作流在归一化项目名与 emoji 后逐字相同（GitHub 与 Gitea 之间仍按 6.2
   保留固有差异）。
2. **代码层四项已统一**：`lib/services/log_service.dart` 7 份逐字节一致；
   设置页日志查看 UI 7 份齐备；日志目录落点统一为
   `<用户可见根>/<应用目录>/logs>`；FileSystemService 的
   `_baseDir` / `getLogRoot` / `openDirectory` 7 份逐字一致。
3. **A 类差异已全部关闭**：7 个仓库均有 FSS，tetris 的内联实现已移除。
4. 其余为仓库卫生差异（racing 缺 `prompt.md`、`diff.md` 仅 bilibili）与
   业务差异（依赖、包名、assets、权限、横屏），不建议强行统一。

## 1. 项目概览

| 项                            | bilibili                | gomoku             | music             | racing             | snake             | tank                    | tetris             |
| ----------------------------- | ----------------------- | ------------------ | ----------------- | ------------------ | ----------------- | ----------------------- | ------------------ |
| 应用类型                      | Bilibili 下载器         | 五子棋             | 本地音乐播放器    | 赛车游戏           | 贪吃蛇            | 坦克大战                | 俄罗斯方块         |
| 版本号（pubspec）             | 0.4.34                  | 0.3.9              | 0.3.50            | 0.1.3              | 0.3.5             | 0.3.3                   | 0.6.4              |
| applicationId / namespace     | com.bilibili.downloader | com.flutter.gomoku | com.flutter.music | com.flutter.racing | com.flutter.snake | com.flutter.tank_battle | com.flutter.tetris |
| rootProject.name              | bilibili_downloader     | flutter_gomoku     | flutter_music     | flutter_racing     | flutter_snake     | flutter_tank_battle     | flutter_tetris     |
| 正式 keystore（android/app/） | bilibili-downloader.jks | flutter-gomoku.jks | flutter-music.jks | flutter-racing.jks | flutter-snake.jks | flutter-tank-battle.jks | flutter-tetris.jks |
| 业务依赖                      | 见 3.2                  | 仅 path            | 见 3.2            | audioplayers       | audioplayers      | audioplayers            | audioplayers       |
| assets/                       | 无                      | 无                 | 无                | audio/             | 无                | audio/                  | 无                 |
| lib Dart 文件数               | 29                      | 21                 | 30                | 30                 | 17                | 27                      | 29                 |
| test 文件数                   | 3                       | 9                  | 10                | 11                 | 5                 | 7                       | 14                 |

## 2. Dart / Flutter 环境（完全一致）

| 配置            | 7 项目统一值                                                         |
| --------------- | -------------------------------------------------------------------- |
| Dart SDK 约束   | `>=3.13.5 <4.0.0`                                                    |
| CI Flutter 版本 | `3.47.7`（GitHub workflow env `FLUTTER_VERSION`；Gitea runner 预装） |
| CI JDK          | Temurin 21（GitHub workflow env `JAVA_VERSION`；Gitea runner 预装）  |

## 3. pubspec.yaml 依赖对比

### 3.1 共有依赖（已全部对齐）

| 依赖                  | 7 项目统一值 |
| --------------------- | ------------ |
| provider              | 6.1.5+1      |
| shared_preferences    | 2.5.6        |
| path_provider         | 2.1.6        |
| window_manager        | 0.5.2        |
| flutter_localizations | sdk: flutter |
| flutter_lints（dev）  | 6.0.0        |

注：`path` 在 bilibili 以外的 6 个项目为直接依赖（1.9.1），bilibili 未直接声明。

### 3.2 各项目独有依赖（业务决定，不属于基础依赖）

| 项目     | 独有依赖                                                                                                                                                            |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bilibili | dio 5.11.1、intl 0.20.3、crypto 3.0.7、flutter_local_notifications 22.3.2、url_launcher 6.3.3、ffmpeg_kit_extended_flutter 0.6.2（三平台原生库走 gh-proxy）         |
| gomoku   | 无（仅 path）                                                                                                                                                       |
| music    | just_audio 0.10.6、just_audio_windows 0.2.3、audio_service 0.18.19、audio_session 0.2.4、audio_metadata_reader 1.8.1、file_picker 13.1.0、permission_handler 13.0.2 |
| racing   | audioplayers 6.8.1                                                                                                                                                  |
| snake    | audioplayers 6.8.1                                                                                                                                                  |
| tank     | audioplayers 6.8.1                                                                                                                                                  |
| tetris   | audioplayers 6.8.1                                                                                                                                                  |

## 4. Android 构建配置

### 4.1 完全一致

| 配置                            | 7 项目统一值                                                                                         |
| ------------------------------- | ---------------------------------------------------------------------------------------------------- |
| AGP                             | 9.4.1（settings.gradle 插件声明）                                                                    |
| Kotlin                          | 2.4.21（插件 + kotlin-stdlib）                                                                       |
| Gradle                          | 9.8.2-all（华为云镜像 distributionUrl）                                                              |
| compileSdk / targetSdk / minSdk | 37.2 / 37 / 35                                                                                       |
| NDK                             | 30.0.16248370                                                                                        |
| Java 兼容性                     | VERSION_21 + jvmTarget 21                                                                            |
| coreLibraryDesugaring           | 2.1.5（启用）                                                                                        |
| ABI                             | 仅 arm64-v8a                                                                                         |
| R8 / 资源收缩                   | `minifyEnabled false` + `shrinkResources false`（全关）                                              |
| Gradle 资源限制                 | `-Xmx3G`、`workers.max=2`、`parallel=false`、`ActiveProcessorCount=4`                                |
| Kotlin 守护进程                 | `kotlin.daemon.jvmargs=-Xmx1G -XX:MaxMetaspaceSize=256m -XX:ActiveProcessorCount=4`                  |
| gradle.properties 其余项        | useAndroidX、newDsl=false、builtInKotlin=false、kotlin.incremental=false                             |
| Maven 镜像机制                  | 阿里云 public/google/gradle-plugin 三项 + `mavenCentral()` + `google()`；`USE_ALIYUN_MAVEN` 条件启用 |

以下文件逐字一致：`analysis_options.yaml`（7 份，md5 `0b5e2c78`）、
`android/gradle/wrapper/gradle-wrapper.properties`（md5 `ed29e8b7`）、
`android/gradle/init-aliyun-mirror.gradle`（md5 `e57cb091`）、
`android/build.gradle`（md5 `51dddb34`）、`android/gradle.properties`
（md5 `b77f3e3d`）、`.build/query_all_versions.py`（md5 `f191bb70`）。
`android/settings.gradle` 与 `android/app/build.gradle` 归一化项目标识符后
7 份无差异。

### 4.2 签名策略（已统一）

7 个项目机制一致：`android/key.properties` + `android/app/<应用名>.jks`，
debug 与 release 均指向 `signingConfigs.release`，签名材料随仓库分发，
`.gitignore` 无签名相关忽略项，CI 直接出包。`signingConfigs` 两行注释措辞
本轮已统一为同一版本。

### 4.3 剩余差异（应用标识与装饰为主）

| 差异点                                       | 现状                       |
| -------------------------------------------- | -------------------------- |
| namespace / applicationId / rootProject.name | 各项目自有标识（正常差异） |
| keystore 文件名                              | 各项目自有（正常差异）     |
| strings.xml 中的应用名                       | 各项目业务名称（正常差异） |

上一版记录的 gradle.properties 注释、兜底版本 `0.1.3`、Maven 镜像两套、
签名注释三种措辞均已关闭。

7 个项目的 `android/build.gradle` 均通过 `subprojects` 对非 `:app` 子项目
设置 `afterEvaluate`（`:app` 自身已设置 37.2），把所有插件模块（含
`file_picker` 的 `android_file_picker`）强制为 `compileSdk 37.2`，避免插件
按 Flutter 默认的 36 编译并引入 Build Tools 36。

### 4.4 应用清单差异（部分属业务决定）

| 项                | bilibili                | gomoku           | music                             | racing           | snake            | tank             | tetris           |
| ----------------- | ----------------------- | ---------------- | --------------------------------- | ---------------- | ---------------- | ---------------- | ---------------- |
| 应用名来源        | @string/app_name        | @string/app_name | @string/app_name                  | @string/app_name | @string/app_name | @string/app_name | @string/app_name |
| strings.xml       | 有                      | 有               | 有                                | 有               | 有               | 有               | 有               |
| INTERNET 权限     | 有                      | 有               | 无                                | 无               | 无               | 无               | 无               |
| 其他组件/权限     | FileProvider、cleartext | —                | 媒体/通知/前台服务 + AudioService | —                | —                | —                | —                |
| screenOrientation | —                       | —                | —                                 | landscape        | —                | —                | —                |

## 5. analysis_options.yaml（lint）

7 份逐字一致（md5 `0b5e2c78`）：`include: package:flutter_lints/flutter.yaml`
之上 13 条规则配置，`avoid_print` 显式关闭，其余启用。

## 6. CI 工作流对比

7 个项目均为双轨制：`.github/workflows/build.yml` + `.gitea/workflows/build.yml`。
归一化项目名与 `run-name` emoji 后，7 份 GitHub 工作流彼此无差异，
7 份 Gitea 工作流同样无差异。以下内容完全一致：

- 触发：push tag `v*` + workflow_dispatch；`concurrency` 按 sha 分组并取消旧构建
- 命名：workflow / run-name / job / step 全部中文 + emoji
- 版本号：从 `pubspec.yaml` 解析，tag 触发时优先取 tag 中的版本
- 流水线：metadata → test（`flutter analyze --no-fatal-infos --no-fatal-warnings`
    + `flutter test --concurrency=2`）→ build-android ∥ build-windows → release
- 超时：Android / Windows 构建 job 均 `timeout-minutes: 30`（GitHub 与 Gitea 一致）
- Windows 构建：复制到短路径 `C:\w`（`cygpath` + `cp -a`）→ `pub get`
  → `flutter create --platforms=windows` → 构建；构建时设
  `CMAKE_BUILD_PARALLEL_LEVEL: 2`
- ZIP 打包：pwsh `Compress-Archive`
- 产物命名：`{仓库名}-{版本}-android-aarch64.apk` / `-windows-x86_64.zip`
- GitHub 产物保留 1 天；prerelease 自动识别 `-rc` / `-beta`
- changelog 排除 docs、.github、.gitea

### 6.1 项目专属差异

| 差异点         | bilibili | gomoku | music | racing | snake | tank | tetris |
| -------------- | -------- | ------ | ----- | ------ | ----- | ---- | ------ |
| run-name emoji | 📺       | ♟️      | 🎵    | 🏁     | 🐍    | 🪖   | 🎮     |
| CMP0091 步骤   | 无       | 无     | 无    | 有     | 有    | 有   | 有     |

CMP0091 与依赖严格对应：使用 `audioplayers 6.8.1` 的 racing / snake / tank /
tetris 需要该步骤，其余 3 个不需要。GitHub `windows-latest` 已指向 VS 2026
镜像，`audioplayers_windows` 4.4.1 要求 CMP0091 NEW；sed 在
`cmake_minimum_required` 行后插入策略并用 grep 校验，模板失配时显式失败。


### 6.2 GitHub 与 Gitea 双轨之间的固有差异

| 维度     | GitHub Actions                                                    | Gitea Actions                                                                                                                           |
| -------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| runner   | ubuntu-latest / windows-latest                                    | ubuntu-flutter / windows-flutter（自建，预装 Flutter/JDK）                                                                              |
| 环境准备 | subosito/flutter-action@v2（3.47.7）+ setup-java@v5（temurin 21） | 无 setup 步骤；构建前做环境诊断（flutter doctor、storage.flutter-io.cn 连通性）并部署 `init-aliyun-mirror.gradle` 到 `~/.gradle/init.d` |
| 产物传递 | upload-artifact@v7 / download-artifact@v8（merge-multiple）       | gitea-upload-artifact@v4 / gitea-download-artifact@v8（release 按名逐个下载）                                                           |
| release  | softprops/action-gh-release@v3                                    | `GITEA_TOKEN` + curl 直调 Gitea API                                                                                                     |

资源限制两轨一致：Gradle `-Xmx3G` / 2 workers、测试 `--concurrency=2`、
Windows CMake 并行 2、构建 job 30 分钟超时。

## 7. 仓库卫生与工程结构

### 7.1 `.metadata` 与 `.gitignore`（已统一）

| 项                | bilibili | gomoku | music          | racing  | snake | tank    | tetris |
| ----------------- | -------- | ------ | -------------- | ------- | ----- | ------- | ------ |
| `.metadata` 入库  | 否       | 否     | 否             | 否      | 否    | 否      | 否     |
| `.gitignore` 模板 | E+下载   | E      | E              | E+tools | E     | E+tools | E      |
| `windows/` 入库   | 无       | 无     | CMakeLists.txt | 无      | 无    | 无      | 无     |
| 版本脚本          | 新       | 新     | 新             | 新      | 新    | 新      | 新     |
| prompt.md         | 有       | 有     | 有             | 无      | 有    | 有      | 有     |

模板定义（以 E 为基准，7 份只差项目特有忽略项）：

- **E（基准）**：忽略 `.metadata`、`.flutter-plugins`、
  `.flutter-plugins-dependencies`；整目录忽略 `windows/`、`macos/`、`ios/`、
  `linux/`、`web/`；忽略 Android 构建产物、`*.log`、`.env`、`token`；
  末尾忽略 `.qwen`。
- **bilibili**：E + `downloads/`、`*.mp4`。
- **racing / tank**：E + `tools/`（两份逐字一致）。

A1 已收尾：gomoku / racing / tank 的 `.metadata` 已用 `git rm --cached`
移出索引（本地文件保留），`git check-ignore` 确认忽略规则生效；
`.gitignore` 由 5 套收敛为「1 份基准 + 2 组项目特有项」。

### 7.2 windows/ 策略

只有 music 入库 `windows/CMakeLists.txt`，其余 6 个完全交给 CI 的
`flutter create` 生成（该命令不覆盖已存在文件，只补 `runner/`、`flutter/`
等缺失部分）。

该文件是 2026-06-09 提交 `3ce1078` 为解决 Windows 构建失败而加的，
其中 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` **不是历史残留**，
而是 music 独有的硬依赖：

- music 的 Windows 原生栈是 `just_audio_windows 0.2.3` 与
  `permission_handler_windows`，两者都拉 C++/WinRT `2.0.210806.1` 并按 C++17 编译；
- 该版本 C++/WinRT 的 `strings/base_includes.h` 在 `__cpp_lib_coroutine`
  未定义（`/std:c++17` 即如此）时 `#include <experimental/coroutine>`；
- MSVC STL 对 `<experimental/coroutine>` 直接报硬错误 STL1011，
  只有定义该宏才能通过编译。

因此宏必须保留；删掉该文件（交给 CI 重新生成）会在编译 `just_audio_windows`
时报 STL1011。`audioplayers 6.8.1` 改用 WIL + C++20，不受此约束。

### 7.3 版本脚本与 versions.md

`.build/query_all_versions.py` 本轮统一为同一代（md5 `f191bb70`，547 行）：
工作流文件不存在时跳过，单流水线时文案改为「GitHub Actions 流水线」。
7 份 `versions.md` 结构一致，应用版本已同步到本版（0.4.34 / 0.3.9 /
0.3.50 / 0.1.3 / 0.3.5 / 0.3.3 / 0.6.4），与 `pubspec.yaml` 一致。

### 7.4 文档齐套性

- `plan.md`：7 个均有。
- `prompt.md`：racing 缺。
- `diff.md`：仅 bilibili（本文档）。
- `README.md`：7 个均有。

## 8. 代码层共享组件

### 8.1 LogService（已统一）

7 份 `lib/services/log_service.dart` 逐字节一致（md5 `b709171b`，218 行）：
早期缓冲 500 + 内存缓冲 2000 + 目录不可用降级内存模式；7 天 mtime 清理、
5MB 轮转 `app_YYYYMMDD_N.log`；`init({required logRoot, clock?})` 注入目录。

### 8.2 设置页日志 UI（已统一）

7 份设置页均有「日志目录」tile（复制路径 + 桌面端打开目录）与「查看日志」
弹窗（刷新 / 复制全部 / 关闭，200 行 monospace `SelectableText`）；
刷新按钮使用 `StatefulBuilder` 重建，修复了父级 `setState` 不刷新弹窗的问题。
bilibili 与 tetris 的「日志目录」字符串各出现 2 次（其余 3 次），
tetris 已改调 `FileSystemService.openDirectory`，实现位置差异已消除。

### 8.3 FileSystemService 与日志落点（已统一）

| 项目     | 行数 | 公开方法                                                                                                   |
| -------- | ---- | ---------------------------------------------------------------------------------------------------------- |
| bilibili | 266  | getDownloadRoot、getLogRoot、revealInFileManager、openDirectory、openWithSystemPlayer、mergeAv、probeMedia |
| gomoku   | 62   | getLogRoot、openDirectory                                                                                  |
| music    | 110  | getUserRoot、getLogRoot、getDefaultMusicDirs、openDirectory                                                |
| racing   | 62   | getLogRoot、openDirectory                                                                                  |
| snake    | 78   | getUserRoot、getLogRoot、openDirectory                                                                     |
| tank     | 62   | getLogRoot、openDirectory                                                                                  |
| tetris   | 62   | getLogRoot、openDirectory                                                                                  |

7 份的 `_baseDir`、`getLogRoot`、`openDirectory` 逐字一致（仅 `appDirName`
不同）；bilibili 的下载/播放/ffmpeg 方法与 music 的默认音乐目录方法保留在
各自文件中。

日志目录本轮已统一为 `<用户可见根>/<应用目录>/logs>`：

| 项目     | 日志目录                                          |
| -------- | ------------------------------------------------- |
| bilibili | `<Documents 或 external>/BilibiliDownloader/logs` |
| gomoku   | `<Documents 或 external>/FlutterGomoku/logs`      |
| music    | `<Documents 或 external>/FlutterMusic/logs`       |
| racing   | `<Documents 或 external>/FlutterRacing/logs`      |
| snake    | `<Documents 或 external>/FlutterSnake/logs`       |
| tank     | `<Documents 或 external>/TankBattle/logs`         |
| tetris   | `<Documents 或 external>/FlutterTetris/logs`      |

Android 优先 `getExternalStorageDirectory()`，其余平台用 Documents。

### 8.4 目录结构差异

| 项目     | 特有目录                                       | lib Dart 数 | test 文件数 |
| -------- | ---------------------------------------------- | ----------- | ----------- |
| bilibili | 无 widgets/；主题文件为 `china_app_theme.dart` | 29          | 3           |
| gomoku   | `ai/`                                          | 21          | 9           |
| music    | 无                                             | 30          | 10          |
| racing   | `engine/`                                      | 30          | 11          |
| snake    | 无                                             | 17          | 5           |
| tank     | `engine/`                                      | 27          | 7           |
| tetris   | 无                                             | 29          | 14          |

bilibili 的主题文件名与其余 6 个（`app_theme.dart`）不同，属命名差异。

## 9. 差异分级

### A 类：仍建议统一

无。上一版 9 项已全部关闭。

### A 类关闭记录

| 编号 | 差异                                 | 处理结果                                                |
| ---- | ------------------------------------ | ------------------------------------------------------- |
| A1   | `.metadata` 索引 + `.gitignore` 多套 | 3 个仓库已 `git rm --cached`，模板收敛为 E + 项目特有项 |
| A2   | 日志目录 5 种落点                    | 7 个项目统一为 `<用户根>/<应用目录>/logs>`              |
| A3   | GitHub changelog 缺 `.gitea`         | gomoku 已补，7 份工作流归一化后无差异                   |
| A4   | 版本脚本两代                         | 7 份统一为 md5 `f191bb70`                               |
| A5   | Maven 镜像两套                       | 统一 3 项阿里云 + `mavenCentral()` + `google()`         |
| A6   | 兜底版本 `0.1.3`                     | 统一为 `0.1.0`                                          |
| A7   | 唯一入库 windows 工程文件            | 保留（`just_audio_windows` 编译必需，见 7.2）           |
| A8   | 应用名资源化不一致                   | 7 个均改为 `@string/app_name`，`strings.xml` 齐备       |
| A9   | FSS 6 份实现 + tetris 内联           | 7 份公共方法逐字一致，tetris 补齐 FSS 并移除内联        |

### B 类：装饰或卫生，可顺手

- racing 缺 `prompt.md`。
- bilibili 主题文件名 `china_app_theme.dart`。
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
- CI 资源限制的具体数值（3G 堆 / 2 workers / 测试并发 2 / CMake 并行 2）
  与自建 runner 规格绑定，可按机器能力调整。

## 10. 演进路线

### P0 仓库卫生

1. 已完成：gomoku / racing / tank 的 `.metadata` 已移出索引，`.gitignore`
   统一为 E 基准（bilibili 加 `downloads/`、`*.mp4`，racing / tank 加 `tools/`）。
2. 剩余：racing 补 `prompt.md`；后续文档变更时同步 `diff.md`。

### P1 构建配置对齐

4. 本轮已完成：Maven 镜像、兜底版本、签名注释、gradle.properties 注释、
   应用名资源化、版本脚本、超时与资源限制。
5. music 的 `windows/CMakeLists.txt` 保留现状（见 7.2）。

### P2 代码层最小契约

6. 已完成：`FileSystemService` 收敛为「单例 + `getLogRoot` + `openDirectory`」，
   项目特有方法保留；tetris 已补齐 FSS 并移除内联。
7. 日志目录约定已落地，后续新增项目直接沿用。
8. `log_service_test.dart` 已一致，无需改动；FSS 暂无独立测试，由 CI 验证。

### P3 版本演进

9. 工具链保持一致升级节奏：先 bilibili + racing 验证，通过后回填其余 5 个。
10. 每次改动先用 `workflow_dispatch` 触发双轨构建验证，再打 tag。

## 11. 差异之外的提醒

- `audioplayers 6.8.1`（racing / snake / tank / tetris）：workflow 中的
  CMP0091 步骤是上游对 VS 2026 的明确要求，升级前先重查其
  `audioplayers_windows` 的 README/CMake 要求，不要顺手删除。
- `ffmpeg_kit_extended_flutter`（bilibili）原生库三平台走 gh-proxy，
  是该网络环境下的特例配置。
- CI 资源限制（Gradle `-Xmx3G`、2 workers、测试并发 2、CMake 并行 2、
  30 分钟超时）是为自建 runner 与 GitHub 免费 runner 的稳定性加的，
  调整前先确认 runner 的 CPU / 内存规格。
- 7 个项目 CI 的 Flutter / JDK / AGP / Kotlin / Gradle 完全同版本，
  工具链层面不存在分叉；后续升级建议同步推进。
- 本机 `flutter` / `dart` CLI 不可用，本文档所有结论来自静态文件核对，
  未运行 `flutter analyze` / `flutter test`；改动需依赖 CI 双轨验证。

## 12. 提交索引（备查）

**第一轮统一（2026-10-17 ~ 10-19 上午，均已提交）**

| 项目                 | 相关提交                                                                                                                               |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
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

**第三轮整改（2026-10-23，已推送 tag）**

| 项目     | 本轮提交                                                                                                                                                                     |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bilibili | 8effe15 超时、eda897d 版本脚本、ff3eab3 日志目录、079daab 应用名、feb859f gradle 注释、29351f4 资源限制、f19431a 测试并发、3a60ec3 文档更正、7b61a8c 发版                    |
| gomoku   | b32153f 超时 + .gitea 排除、3039d47 版本脚本、d50ed7e 忽略 .metadata、3362836 应用名、ca088f1 兜底 0.1.0、e787ddf 日志目录、a2cafde 资源限制、9883466 测试并发、450e23e 发版 |
| music    | e2a9b56 超时、bb2d169 版本脚本、2d04756 资源限制、2f29e08 测试并发、74a6163 发版                                                                                             |
| racing   | af152f9 超时、b637e66 忽略 .metadata、90ccc00 Maven 精简、d8c77af 签名注释、3073a3a 资源限制、d5d3d8a 测试并发、53cdd66 发版                                                 |
| snake    | 28619c5 超时、6b29e6c 版本脚本、0e966b0 应用名、71fe931 资源限制、b129208 测试并发、1b44898 发版                                                                             |
| tank     | 12f4e9b 超时、1b67d16 忽略 .metadata、fbdc397 Maven 精简、93b8899 签名注释、4fa42ae 资源限制、64ee8ec 测试并发、1f69f58 发版                                                 |
| tetris   | 2104c7c 超时、ec873e9 版本脚本、cc883fa 日志目录、4346b3c 资源限制、d571792 测试并发、bf48750 发版                                                                           |

**A1 收尾（2026-10-23，tag 后新增，未推送）**

| 项目     | 提交    | 内容                                  |
| -------- | ------- | ------------------------------------- |
| bilibili | a770fc4 | 统一 .gitignore 模板                  |
| gomoku   | a64487b | 统一 .gitignore + 移除 .metadata 索引 |
| music    | 761a2a5 | 统一 .gitignore 模板                  |
| racing   | 7f6e0a2 | 移除 .metadata 索引                   |
| tank     | 4d1368f | 移除 .metadata 索引                   |
| snake    | —       | 已是基准模板，无改动                  |
| tetris   | —       | 已是基准模板，无改动                  |

**A9 收尾（2026-10-23，tag 后新增，未推送）**

| 项目     | 提交    | 内容                                |
| -------- | ------- | ----------------------------------- |
| bilibili | fa3ca8b | 统一 FSS 最小契约                   |
| gomoku   | b4aa7d6 | 统一 FSS 最小契约                   |
| music    | 09eb566 | 统一 FSS 最小契约                   |
| racing   | 0e8ed61 | 统一 FSS 最小契约                   |
| snake    | c1a2e13 | 统一 FSS 最小契约                   |
| tank     | f99ae0a | 统一 FSS 最小契约                   |
| tetris   | 5e40235 | 新增 FSS，移除 main / settings 内联 |

**当前 HEAD（2026-10-23 核对；tag 见上表，A1 / A9 收尾提交未推送）**

| 项目     | HEAD    | tag     |
| -------- | ------- | ------- |
| bilibili | cb2a5de | v0.4.34 |
| gomoku   | b4aa7d6 | v0.3.9  |
| music    | 09eb566 | v0.3.50 |
| racing   | 0e8ed61 | v0.1.3  |
| snake    | c1a2e13 | v0.3.5  |
| tank     | f99ae0a | v0.3.3  |
| tetris   | 5e40235 | v0.6.4  |
