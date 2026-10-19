# 四项目配置差异对比

> 对比时间：2026-10-19（第二轮清理后复查；四仓库本轮改动待提交）
> 对比范围：pubspec.yaml 依赖、Android 构建配置与签名、analysis_options（lint）、
> CI 工作流（GitHub + Gitea）、目录结构与辅助文件（versions.md、.build、.metadata 等）
> 项目清单：`flutter-bilibili-downloader-d4-qwen-code`（下称 bilibili）、`flutter-music`、
> `flutter-snake`、`flutter-tetris`
>
> **第二轮清理（2026-10-19 下午）**：① 移除 bilibili 的 ffmpeg-kit 钩子失败日志导出步骤；② snake/tetris
> `audioplayers` 升级 6.5.1 → 6.8.1，旧的协程静默 CMake 补丁作废，按上游要求换成 CMP0091 策略步骤
> （见 6.1）；③ 三仓库删除 `.metadata`（四仓库 .gitignore 均已忽略）与残留 `debug.keystore`；
> ④ snake MainActivity 迁移 Kotlin 并删除 src/debug、src/profile 清单；⑤ bilibili `flutterVersionName`
> 兜底统一 `0.1.0`。第一轮统一（同日上午）消除的 5 处分叉见文末提交索引。

## 0. 结论速览

工程模板层面四个项目**已完全统一**，逐项核对全部通过：

1. **工具链**：AGP / Gradle / Kotlin / compileSdk / targetSdk / minSdk / NDK / JDK / R8 策略完全一致
2. **基础依赖**：provider、shared_preferences、path_provider、window_manager、flutter_lints 版本全部一致
3. **lint**：`analysis_options.yaml` 四项目逐字一致（flutter_lints 基础 + 13 条规则配置）
4. **签名**：四项目均使用 `key.properties` + 正式 jks，debug/release 同签名，材料随仓库分发
5. **workflow**：双流水线统一为 bilibili 模板（中文名称/日志、Windows 短路径 `C:\w`、bash 复制、
   pwsh 打 ZIP、changelog 排除 docs/.github/.gitea），项目专属步骤仅剩 6.1 节所列两项
6. **versions.md 机制**：`.build/query_all_versions.py`（四项目同一份脚本）+ 各自生成的清单均已就位

剩余差异集中在 3.2 节（业务依赖）、4.3 节（应用标识）、6.1 节（workflow 专属步骤），
均为有意保留，不构成需要处理的分叉。

## 1. 项目概览

| 项                            | bilibili                       | music                                         | snake                         | tetris                        |
| ----------------------------- | ------------------------------ | --------------------------------------------- | ----------------------------- | ----------------------------- |
| 应用类型                      | Bilibili 下载器                | 本地音乐播放器                                | 贪吃蛇                        | 俄罗斯方块                    |
| 版本号（pubspec）             | 0.4.31                         | 0.3.46                                        | 0.3.1                         | 0.6.0                         |
| applicationId / namespace     | com.bilibili.downloader        | com.flutter.music                             | com.flutter.snake             | com.flutter.tetris            |
| rootProject.name              | bilibili_downloader            | flutter_music                                 | flutter_snake                 | flutter_tetris                |
| 正式 keystore（android/app/） | bilibili-downloader.jks        | flutter-music.jks                             | flutter-snake.jks             | flutter-tetris.jks            |
| debug.keystore                | 无                             | 无（已删除）                                  | 无（已删除）                  | 无（已删除）                  |
| windows/ 目录                 | 无（CI `flutter create` 生成） | 仅 CMakeLists.txt 入库，其余不入库、CI 端重建 | 无（CI 生成）                 | 无（CI 生成）                 |
| .metadata                     | 无（.gitignore 忽略）          | 无（已删除，.gitignore 忽略）                 | 无（已删除，.gitignore 忽略） | 无（已删除，.gitignore 忽略） |
| versions.md + .build/         | 有                             | 有                                            | 有                            | 有                            |
| MainActivity                  | Kotlin                         | Kotlin（另有 MainApplication.kt）             | Kotlin（已由 Java 迁移）      | Kotlin                        |

## 2. Dart / Flutter 环境（完全一致，无需动）

| 配置            | 四项目统一值                                                         |
| --------------- | -------------------------------------------------------------------- |
| Dart SDK 约束   | `>=3.13.5 <4.0.0`                                                    |
| CI Flutter 版本 | `3.47.7`（GitHub workflow env `FLUTTER_VERSION`；Gitea runner 预装） |
| CI JDK          | Temurin 21（GitHub workflow env `JAVA_VERSION`；Gitea runner 预装）  |

## 3. pubspec.yaml 依赖对比

### 3.1 共有依赖（已全部对齐 ✅）

| 依赖                  | 四项目统一值 |
| --------------------- | ------------ |
| provider              | 6.1.5+1      |
| shared_preferences    | 2.5.6        |
| path_provider         | 2.1.6        |
| window_manager        | 0.5.2        |
| flutter_localizations | sdk: flutter |
| flutter_lints（dev）  | 6.0.0        |

注：`path` 在 music/snake/tetris 为直接依赖（1.9.1），bilibili 未直接声明（仅传递依赖）。

### 3.2 各项目独有依赖（业务决定，不属于"基础依赖"）

| 项目     | 独有依赖                                                                                                                                                                                 |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bilibili | dio 5.11.1、intl 0.20.3、crypto 3.0.7、flutter_local_notifications 22.3.2、url_launcher 6.3.3、ffmpeg_kit_extended_flutter 0.6.2（Android/Linux/Windows 三平台原生库均走 gh-proxy 下载） |
| music    | path 1.9.1、just_audio 0.10.5、just_audio_windows 0.2.3、audio_service 0.18.18、audio_session 0.2.3、audio_metadata_reader 1.6.0、file_picker 10.3.10、permission_handler 12.0.3         |
| snake    | path 1.9.1、audioplayers 6.8.1                                                                                                                                                           |
| tetris   | path 1.9.1、audioplayers 6.8.1                                                                                                                                                           |

## 4. Android 构建配置

### 4.1 完全一致（逐项核对通过）

| 配置                            | 四项目统一值                                                                                                |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| AGP                             | 9.2.1（settings.gradle 插件声明）                                                                           |
| Kotlin                          | 2.3.21（插件 + kotlin-stdlib）                                                                              |
| Gradle                          | 9.5.1-all（华为云镜像 distributionUrl）                                                                     |
| compileSdk / targetSdk / minSdk | 37 / 37 / 35                                                                                                |
| NDK                             | 30.0.16248370                                                                                               |
| Java 兼容性                     | VERSION_21 + jvmTarget 21                                                                                   |
| coreLibraryDesugaring           | 2.1.5（启用）                                                                                               |
| ABI                             | 仅 arm64-v8a                                                                                                |
| R8 / 资源收缩                   | `minifyEnabled false` + `shrinkResources false`（全关，无 proguard 规则）                                   |
| flutterVersionName 兜底默认值   | `0.1.0`（已统一）                                                                                           |
| gradle.properties 配置项        | -Xmx4G、useAndroidX、newDsl=false、builtInKotlin=false、kotlin.incremental=false                            |
| Maven 镜像                      | `USE_ALIYUN_MAVEN` 条件启用阿里云镜像（settings/build.gradle + `android/gradle/init-aliyun-mirror.gradle`） |

以下文件四项目**逐字一致**：`analysis_options.yaml`、`android/build.gradle`、
`android/gradle/init-aliyun-mirror.gradle`、`android/gradle/wrapper/gradle-wrapper.properties`、
`.build/query_all_versions.py`（`android/gradle.properties` 仅差注释行，见 4.3）。

### 4.2 签名策略（已统一 ✅）

四项目机制完全一致：`android/key.properties` + `android/app/<应用名>.jks` 正式密钥
（有效期 36500 天），build.gradle 中 debug 与 release 两个 buildType 均指向同一
`signingConfigs.release`，签名材料随仓库分发、CI 直接出包；四仓库 `.gitignore` 均无
签名相关忽略项。

### 4.3 剩余差异（应用标识与装饰差异，无功能影响）

| 差异点                                       | 说明                                                                                                                       |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| namespace / applicationId / rootProject.name | 各项目自有标识（正常差异）                                                                                                 |
| gradle.properties                            | bilibili 多两行注释（builtInKotlin 来源、kotlin.incremental 关闭原因）且带末尾换行，其余三个无注释；**配置项本身完全一致** |

## 5. analysis_options.yaml（lint）

四项目**逐字一致**：`include: package:flutter_lints/flutter.yaml` 之上共 13 条规则配置
（require_trailing_commas、prefer_final_locals、prefer_single_quotes、sort_child_properties_last、
prefer_const 系列、unnecessary_library_name、avoid_redundant_argument_values 等 12 条启用，
avoid_print 显式关闭）。

## 6. CI 工作流对比

四项目均为双轨制：`.github/workflows/build.yml`（GitHub Actions）+ `.gitea/workflows/build.yml`
（Gitea Actions，自托管 runner），模板统一为 bilibili 版本。以下内容四项目完全一致：

- 触发：push tag `v*` + workflow_dispatch；`concurrency` 按 sha 分组并取消进行中的旧构建
- 命名：workflow / run-name / job / step 全部中文 + emoji；run-name 为"emoji + 构建 +
  ref_name"，各项目仅 emoji 不同（bilibili 📺 / music 🎵 / snake 🐍 / tetris 🎮）
- 版本号：从 `pubspec.yaml` 解析（tag 触发时优先取 tag 中的版本），项目名由仓库名 `-`→`_` 得出
- 流水线：metadata → test（`flutter analyze` + `flutter test`）→ build-android ∥ build-windows → release
- Windows 构建：工程复制到短路径 **`C:\w`**（bash `cygpath` + `cp -a`，规避长路径问题），
  顺序为 `pub get` → `flutter create --platforms=windows` → 构建
- ZIP 打包：pwsh `Compress-Archive`
- 产物命名：`{仓库名}-{版本}-android-aarch64.apk` / `-windows-x86_64.zip`
- changelog 排除目录：docs、.github、.gitea
- prerelease 自动识别 `-rc`/`-beta`

### 6.1 项目专属差异（有意保留）

| 差异点                                                                       | bilibili | music | snake  | tetris |
| ---------------------------------------------------------------------------- | -------- | ----- | ------ | ------ |
| run-name emoji                                                               | 📺       | 🎵    | 🐍     | 🎮     |
| CMakeLists 启用 CMP0091 策略步骤（GitHub/Gitea 均为 bash sed，详见下方说明） | 无       | 无    | **有** | **有** |

**CMP0091 步骤说明**（替换已作废的协程静默补丁）：

- snake/tetris `audioplayers` 升级 6.5.1 → 6.8.1 后，其 Windows 实现 `audioplayers_windows`
  由 3.x 升至 **4.4.1**（C++23 + WIL/Media Engine 全量重写，官方 tarball 源码中
  `<experimental>` / `std::experimental` / `SILENCE_EXPERIMENTAL` 零命中），旧的
  `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` 注入补丁**作废移除**。
- `audioplayers_windows` 4.4.1 README：**Visual Studio 18 (2026)** 下其依赖库要求 CMP0091
  NEW 策略，建议在 flutter 生成的 `windows/CMakeLists.txt` 中启用（`cmake_policy(SET CMP0091 NEW)`
  或 `cmake_minimum_required` 3.15）。
- GitHub `windows-latest` 现指向 **windows-2025-vs2026 镜像（VS 2026 18.10）**，该要求在
  GitHub runner 上会实际生效；Gitea `windows-flutter` runner 的 VS 版本未知，该策略在
  VS 2022 下无副作用，故双轨统一加步骤（sed 在 `cmake_minimum_required` 行后插入
  `cmake_policy(SET CMP0091 NEW)`，grep 校验，模板行变更时会显式失败提醒）。
- 另：bilibili 的"ffmpeg-kit 钩子失败日志导出"步骤（仅 GitHub 版曾有）已移除。

### 6.2 GitHub 与 Gitea 双轨之间的固有差异（四项目一致，属机制差异）

| 维度     | GitHub Actions                                                                           | Gitea Actions                                                                                                                                          |
| -------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| runner   | ubuntu-latest / windows-latest（托管，Windows 现为 windows-2025-vs2026 / VS 2026 18.10） | ubuntu-flutter / windows-flutter（自建，预装 Flutter/JDK，工作流内不固定版本）                                                                         |
| 环境准备 | subosito/flutter-action@v2（3.47.7）+ setup-java@v5（temurin 21，gradle cache）          | 无 setup 步骤；Android 构建前做环境诊断（env + flutter doctor + storage.flutter-io.cn 连通性）并部署 `init-aliyun-mirror.gradle` 到 `~/.gradle/init.d` |
| 超时     | 无特殊设置                                                                               | build job `timeout-minutes: 30`                                                                                                                        |
| 产物传递 | upload-artifact@v7（retention 1 天）/ download-artifact@v8（merge-multiple）             | gitea-upload-artifact@v4 / gitea-download-artifact@v8（release 按名逐个下载，故 needs 含 metadata）                                                    |
| release  | softprops/action-gh-release@v3                                                           | `GITEA_TOKEN` + curl 直调 Gitea API 创建并逐文件上传                                                                                                   |

## 7. 遗留可选清理项

**本轮已完成（2026-10-19 下午，待提交）**：

1. ✅ 移除 bilibili 的 ffmpeg-kit 钩子失败日志导出步骤（GitHub workflow −11 行）
2. ✅ snake/tetris audioplayers 升级 6.8.1，协程静默补丁换成 CMP0091 策略步骤（两份 workflow）
3. ✅ 三仓库删除 `.metadata`，四仓库 `.gitignore` 增加 `.metadata` 忽略
4. ✅ snake MainActivity.java → MainActivity.kt（与其他项目一致，均为 Kotlin）
5. ✅ 三仓库删除残留的 `android/app/debug.keystore`（build.gradle 已全部指向 release 密钥）
6. ✅ snake 删除 src/debug、src/profile 清单（内容仅为 debug/profile 构建声明 INTERNET 权限，
   四项目其余三个均无此文件；唯一影响是本地 `flutter run` 调试联网，本机无 flutter CLI、CI 只出
   release，不受影响）
7. ✅ bilibili flutterVersionName 兜底 `0.1.2` → `0.1.0`（与其余项目一致）

**剩余可选项（未处理）**：

1. **music 的 windows/ 目录策略**：仅 CMakeLists.txt 入库、其余 CI 端由 `flutter create` 重建。
   若无保留它的特殊理由，可移除该文件、完全交给 CI 生成，与另外三项目对齐。
2. **bilibili 的 gradle.properties 注释行**：纯装饰差异（配置项一致），想绝对逐字统一可顺手对齐。

## 8. 差异之外的提醒

- `audioplayers 6.8.1`（snake/tetris）：workflow 中的 CMP0091 策略步骤是上游对 VS 2026 的
  明确要求，升级 audioplayers 前先重查其 `audioplayers_windows` 依赖的 README/CMake 要求，
  不要顺手删步骤，除非确认新版本不再需要；若步骤内 sed 锚点（`cmake_minimum_required` 整行）
  因 Flutter 模板变更失配，grep 会让步骤显式失败提示。
- `ffmpeg_kit_extended_flutter`（bilibili）原生库三平台走 gh-proxy，是该网络环境下的特例配置；
  Windows 侧的"短名重打包"绕行已移除（cbe91d2），钩子直接使用上游 bundle。
- 四项目 CI 的 Flutter/JDK/AGP/Kotlin/Gradle 完全同版本，**工具链层面不存在分叉**；后续升级
  建议保持四项目同步推进，以先验证通过的项目为准回填其余三个（本轮 workflow/依赖/签名演进均
  以 bilibili 为先行）。
- snake/tetris 的 CMP0091 步骤与 audioplayers 6.8.1 尚未经 CI 实跑验证（本机无 flutter CLI），
  建议先以 workflow_dispatch 触发一次双轨构建确认，再打 tag 发布。

## 9. 提交索引（备查，git log 可查）

**第一轮统一（2026-10-17 ~ 10-19 上午，均已提交）**：

| 项目                 | 相关提交                                                                                                                               |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| bilibili（模板先行） | 2890516 workflow 中文名、d1d786e C:\w 短路径、b1af1de bash cp -a、5e33bec 关 R8、58d0fb6 版本脚本通用化、bb55eec changelog 排除 .gitea |
| music                | 737973f 依赖升级、6deab1e 统一签名、f2a5881 Windows 短路径 + 日志统一、2253f36 补齐 lint、c1dd03a versions.md、a72511b 签名材料入库    |
| snake                | 847851e 包名改 com.flutter.snake + 统一签名、19b8845 双流水线优化避长路径、9b4c2a6 依赖升级、0c2f16f versions.md、b7c516d 签名密钥入库 |
| tetris               | c54f066 统一长期签名、14b4c07 依赖升级、0547163 双流水线 Windows 与中文日志、c942031 versions.md、c1cccc8 签名材料入库                 |
| 本文档               | d8afb15 复查结果（已推送）                                                                                                             |

**第二轮清理（2026-10-19 下午，各仓库工作区待提交）**：

| 项目     | 待提交改动                                                                                                                                                                                                                                  |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bilibili | `.github/workflows/build.yml`（移除 ffmpeg-kit 日志导出）、`android/app/build.gradle`（兜底 0.1.0）、`.gitignore`（+.metadata）、`diff.md`（本文档）                                                                                        |
| music    | 删除 `.metadata`、`android/app/debug.keystore`；`.gitignore`（+.metadata）                                                                                                                                                                  |
| snake    | 删除 `.metadata`、`debug.keystore`、`src/debug`、`src/profile` 清单、`MainActivity.java`；新增 Kotlin 版 `MainActivity.kt`；`pubspec.yaml` + `versions.md`（audioplayers 6.8.1）；两份 workflow（CMP0091 步骤）；`.gitignore`（+.metadata） |
| tetris   | 删除 `.metadata`、`android/app/debug.keystore`；`pubspec.yaml` + `versions.md`（audioplayers 6.8.1）；两份 workflow（CMP0091 步骤）；`.gitignore`（+.metadata）                                                                             |
