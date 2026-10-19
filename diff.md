# 四项目配置差异对比

> 对比时间：2026-10-19（统一方案落地后复查；四仓库工作区均为干净状态且已同步远端）
> 对比范围：pubspec.yaml 依赖、Android 构建配置与签名、analysis_options（lint）、
> CI 工作流（GitHub + Gitea）、目录结构与辅助文件（versions.md、.build、.metadata 等）
> 项目清单：`flutter-bilibili-downloader-d4-qwen-code`（下称 bilibili）、`flutter-music`、
> `flutter-snake`、`flutter-tetris`
>
> **本次复查结论**：上一版列出的 5 处分叉（基础依赖版本、签名策略、GitHub workflow 演进、
> music lint 缺口、snake 脚手架 namespace）已全部消除，versions.md 机制也已复制到三项目。
> 当前剩余差异均为 **预期内的项目个性化内容**（业务依赖、应用标识、平台专属补丁/诊断步骤），
> 另有少量可选清理项（见第 7 节）。逐字一致性均已"统一行尾后比较"校验。

## 0. 结论速览

工程模板层面四个项目 **已完全统一**，本次逐项核对全部通过：

1. **工具链**：AGP / Gradle / Kotlin / compileSdk / targetSdk / minSdk / NDK / JDK / R8 策略完全一致
2. **基础依赖**：provider、shared_preferences、path_provider、window_manager、flutter_lints 版本全部一致
3. **lint**：`analysis_options.yaml` 四项目逐字一致（flutter_lints 基础 + 13 条规则配置）
4. **签名**：四项目均使用 `key.properties` + 正式 jks，debug/release 同签名，材料随仓库分发
5. **workflow**：双流水线统一为 bilibili 模板（中文名称/日志、Windows 短路径 `C:\w`、bash 复制、
   pwsh 打 ZIP、changelog 排除 docs/.github/.gitea），仅保留各项目专属补丁/诊断步骤
6. **versions.md 机制**：`.build/query_all_versions.py`（四项目同一份脚本）+ 各自生成的清单均已就位

剩余差异集中在 3.2 节（业务依赖）、4.3 节（应用标识与历史痕迹）、6.1 节（workflow 专属步骤），
均为有意保留，不构成需要处理的分叉。

## 1. 项目概览

| 项                            | bilibili                       | music                                         | snake                                              | tetris             |
|-------------------------------|--------------------------------|-----------------------------------------------|----------------------------------------------------|--------------------|
| 应用类型                      | Bilibili 下载器                | 本地音乐播放器                                | 贪吃蛇                                             | 俄罗斯方块         |
| 版本号（pubspec）             | 0.4.31                         | 0.3.46                                        | 0.3.1                                              | 0.6.0              |
| applicationId / namespace     | com.bilibili.downloader        | com.flutter.music                             | com.flutter.snake                                  | com.flutter.tetris |
| rootProject.name              | bilibili_downloader            | flutter_music                                 | flutter_snake                                      | flutter_tetris     |
| 正式 keystore（android/app/） | bilibili-downloader.jks        | flutter-music.jks                             | flutter-snake.jks                                  | flutter-tetris.jks |
| 残留 debug.keystore           | 无                             | 有（已不被引用）                              | 有（同左）                                         | 有（同左）         |
| windows/ 目录                 | 无（CI `flutter create` 生成） | 仅 CMakeLists.txt 入库，其余不入库、CI 端重建 | 无（CI 生成）                                      | 无（CI 生成）      |
| .metadata                     | 无                             | 有                                            | 有                                                 | 有                 |
| versions.md + .build/         | 有                             | 有                                            | 有                                                 | 有                 |
| MainActivity                  | Kotlin                         | Kotlin（另有 MainApplication.kt）             | **Java**（唯一，另带 src/debug、src/profile 清单） | Kotlin             |

## 2. Dart / Flutter 环境（完全一致，无需动）

| 配置            | 四项目统一值                                                         |
|-----------------|----------------------------------------------------------------------|
| Dart SDK 约束   | `>=3.13.5 <4.0.0`                                                    |
| CI Flutter 版本 | `3.47.7`（GitHub workflow env `FLUTTER_VERSION`；Gitea runner 预装） |
| CI JDK          | Temurin 21（GitHub workflow env `JAVA_VERSION`；Gitea runner 预装）  |

## 3. pubspec.yaml 依赖对比

### 3.1 共有依赖（已全部对齐 ✅）

| 依赖                  | 四项目统一值 |
|-----------------------|--------------|
| provider              | 6.1.5+1      |
| shared_preferences    | 2.5.6        |
| path_provider         | 2.1.6        |
| window_manager        | 0.5.2        |
| flutter_localizations | sdk: flutter |
| flutter_lints（dev）  | 6.0.0        |

注：`path` 在 music/snake/tetris 为直接依赖（1.9.1），bilibili 未直接声明（仅传递依赖）。

### 3.2 各项目独有依赖（业务决定，不属于"基础依赖"）

| 项目     | 独有依赖                                                                                                                                                                                 |
|----------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| bilibili | dio 5.11.1、intl 0.20.3、crypto 3.0.7、flutter_local_notifications 22.3.2、url_launcher 6.3.3、ffmpeg_kit_extended_flutter 0.6.2（Android/Linux/Windows 三平台原生库均走 gh-proxy 下载） |
| music    | path 1.9.1、just_audio 0.10.5、just_audio_windows 0.2.3、audio_service 0.18.18、audio_session 0.2.3、audio_metadata_reader 1.6.0、file_picker 10.3.10、permission_handler 12.0.3         |
| snake    | path 1.9.1、audioplayers 6.5.1                                                                                                                                                           |
| tetris   | path 1.9.1、audioplayers 6.5.1                                                                                                                                                           |

## 4. Android 构建配置

### 4.1 完全一致（逐项核对通过）

| 配置                            | 四项目统一值                                                                                                |
|---------------------------------|-------------------------------------------------------------------------------------------------------------|
| AGP                             | 9.2.1（settings.gradle 插件声明）                                                                           |
| Kotlin                          | 2.3.21（插件 + kotlin-stdlib）                                                                              |
| Gradle                          | 9.5.1-all（华为云镜像 distributionUrl）                                                                     |
| compileSdk / targetSdk / minSdk | 37 / 37 / 35                                                                                                |
| NDK                             | 30.0.16248370                                                                                               |
| Java 兼容性                     | VERSION_21 + jvmTarget 21                                                                                   |
| coreLibraryDesugaring           | 2.1.5（启用）                                                                                               |
| ABI                             | 仅 arm64-v8a                                                                                                |
| R8 / 资源收缩                   | `minifyEnabled false` + `shrinkResources false`（全关，无 proguard 规则）                                   |
| gradle.properties 配置项        | -Xmx4G、useAndroidX、newDsl=false、builtInKotlin=false、kotlin.incremental=false                            |
| Maven 镜像                      | `USE_ALIYUN_MAVEN` 条件启用阿里云镜像（settings/build.gradle + `android/gradle/init-aliyun-mirror.gradle`） |

以下文件四项目 **逐字一致**：`analysis_options.yaml`、`android/build.gradle`、
`android/gradle/init-aliyun-mirror.gradle`、`android/gradle/wrapper/gradle-wrapper.properties`、
`.build/query_all_versions.py`（`android/gradle.properties` 仅差注释行，见 4.3）。

### 4.2 签名策略（已统一 ✅）

四项目机制完全一致：`android/key.properties` + `android/app/<应用名>.jks` 正式密钥
（有效期 36500 天），build.gradle 中 debug 与 release 两个 buildType 均指向同一
`signingConfigs.release`，签名材料随仓库分发、CI 直接出包；四仓库 `.gitignore` 均无
签名相关忽略项。此前"仅 bilibili 有正式签名、其余三个 release 用 debug.keystore"的差异
已消除（旧安装包与新签名不兼容，需卸载重装）。

### 4.3 剩余差异（应用标识与历史痕迹，无功能影响）

| 差异点                                       | 说明                                                                                                                       |
|----------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| namespace / applicationId / rootProject.name | 各项目自有标识（snake 已从 com.example.flutter_snake 改为 com.flutter.snake）                                              |
| gradle.properties                            | bilibili 多两行注释（builtInKotlin 来源、kotlin.incremental 关闭原因）且带末尾换行，其余三个无注释；**配置项本身完全一致** |
| flutterVersionName 兜底默认值                | bilibili 为 `0.1.2`，其余为 `0.1.0`（仅 local.properties 缺失时生效，CI 不受影响）                                         |
| debug.keystore                               | music/snake/tetris 仍跟踪 `android/app/debug.keystore`，但已不被 build.gradle 引用（bilibili 无此文件）                    |
| MainActivity                                 | snake 为 Java 且带 src/debug、src/profile 清单；music 另有 MainApplication.kt；其余为 Kotlin                               |

## 5. analysis_options.yaml（lint）

四项目 **逐字一致**：`include: package:flutter_lints/flutter.yaml` 之上共 13 条规则配置
（require_trailing_commas、prefer_final_locals、prefer_single_quotes、sort_child_properties_last、
prefer_const 系列、unnecessary_library_name、avoid_redundant_argument_values 等 12 条启用，
avoid_print 显式关闭）。music 此前仅有 3 条规则，已补齐至与其余三项目完全一致。

## 6. CI 工作流对比

四项目均为双轨制：`.github/workflows/build.yml`（GitHub Actions）+ `.gitea/workflows/build.yml`
（Gitea Actions，自托管 runner），模板已统一为 bilibili 版本。music/snake/tetris 的两份
workflow 与 bilibili 的差异仅剩 6.1 节所列三点。以下内容四项目完全一致：

- 触发：push tag `v*` + workflow_dispatch；`concurrency` 按 sha 分组并取消进行中的旧构建
- 命名：workflow / run-name / job / step 全部中文 + emoji；run-name 为"emoji + 构建 +
  ref_name"，各项目仅 emoji 不同（bilibili 📺 / music 🎵 / snake 🐍 / tetris 🎮）
- 版本号：从 `pubspec.yaml` 解析（tag 触发时优先取 tag 中的版本），项目名由仓库名 `-`→`_` 得出
- 流水线：metadata → test（`flutter analyze` + `flutter test`）→ build-android ∥ build-windows → release
- Windows 构建：工程复制到短路径 **`C:\w`**（bash `cygpath` + `cp -a`，规避长路径问题），
  顺序为 `pub get` → `flutter create --platforms=windows` → 构建（旧版 create/get 顺序不一致
  的问题已随模板统一）
- ZIP 打包：pwsh `Compress-Archive`（Gitea 旧版的 `tar.exe` 打法已废弃）
- 产物命名：`{仓库名}-{版本}-android-aarch64.apk` / `-windows-x86_64.zip`
- changelog 排除目录：docs、.github、.gitea（tetris 最早引入，四项目均已采纳）
- prerelease 自动识别 `-rc`/`-beta`

### 6.1 项目专属差异（有意保留）

| 差异点                                                                                                                       | bilibili | music | snake  | tetris |
|------------------------------------------------------------------------------------------------------------------------------|----------|-------|--------|--------|
| run-name emoji                                                                                                               | 📺       | 🎵    | 🐍     | 🎮     |
| ffmpeg-kit 钩子失败日志导出（仅 GitHub 版有此步骤）                                                                          | **有**   | 无    | 无     | 无     |
| audioplayers_windows CMake 补丁（注入 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`；GitHub 版 pwsh、Gitea 版 sed） | 无       | 无    | **有** | **有** |

### 6.2 GitHub 与 Gitea 双轨之间的固有差异（四项目一致，属机制差异）

| 维度                | GitHub Actions                                                                  | Gitea Actions                                                                                                                                          |
|---------------------|---------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| runner              | ubuntu-latest / windows-latest（托管）                                          | ubuntu-flutter / windows-flutter（自建，预装 Flutter/JDK，工作流内不固定版本）                                                                         |
| 环境准备            | subosito/flutter-action@v2（3.47.7）+ setup-java@v5（temurin 21，gradle cache） | 无 setup 步骤；Android 构建前做环境诊断（env + flutter doctor + storage.flutter-io.cn 连通性）并部署 `init-aliyun-mirror.gradle` 到 `~/.gradle/init.d` |
| 超时                | 无特殊设置                                                                      | build job `timeout-minutes: 30`                                                                                                                        |
| 产物传递            | upload-artifact@v7（retention 1 天）/ download-artifact@v8（merge-multiple）    | gitea-upload-artifact@v4 / gitea-download-artifact@v8（release 按名逐个下载，故 needs 含 metadata）                                                    |
| release             | softprops/action-gh-release@v3                                                  | `GITEA_TOKEN` + curl 直调 Gitea API 创建并逐文件上传                                                                                                   |
| ffmpeg-kit 失败诊断 | build-windows 含 failure 日志导出步骤                                           | 无（自建 runner 工作区路径短，未暴露过该问题）                                                                                                         |

## 7. 遗留可选清理项（低优先级，均不影响功能）

1. **三项目删除残留的 `android/app/debug.keystore`**：build.gradle 已全部指向 release 密钥，
   该文件不再被引用，仅作为历史痕迹留在仓库里。
2. **bilibili 补 `.metadata`**：官方工具元数据，`flutter create .` 可补回（非必需）。
3. **music 的 windows/ 目录策略**：仅 CMakeLists.txt 入库、其余 CI 端由 `flutter create` 重建。
   若无保留它的特殊理由，可移除该文件、完全交给 CI 生成，与另外三项目对齐。
4. **snake 的 MainActivity.java**：四项目中唯一使用 Java 的（且带 src/debug、src/profile 清单），
   若追求完全一致可迁 Kotlin，纯一致性考量，无功能收益。
5. **纯装饰差异**：bilibili 的 gradle.properties 注释行、flutterVersionName 兜底值（`0.1.2` vs
   `0.1.0`），想绝对逐字统一可顺手对齐。

## 8. 差异之外的提醒

- `audioplayers 6.5.1`（snake/tetris）的 CMake 补丁是 **平台专属 workaround**，升级 audioplayers
  前需确认新版是否已修复，不要因"统一"而顺手删除补丁步骤。
- `ffmpeg_kit_extended_flutter`（bilibili）原生库三平台走 gh-proxy，是该网络环境下的特例配置；
  Windows 侧的"短名重打包"绕行已移除（cbe91d2），钩子直接使用上游 bundle。
- 四项目 CI 的 Flutter/JDK/AGP/Kotlin/Gradle 完全同版本， **工具链层面不存在分叉**；后续升级
  建议保持四项目同步推进，以先验证通过的项目为准回填其余三个（本轮 workflow/依赖/签名演进均
  以 bilibili 为先行）。

## 9. 本轮统一的提交索引（备查，git log 可查）

| 项目                 | 相关提交                                                                                                                               |
|----------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| bilibili（模板先行） | 2890516 workflow 中文名、d1d786e C:\w 短路径、b1af1de bash cp -a、5e33bec 关 R8、58d0fb6 版本脚本通用化、bb55eec changelog 排除 .gitea |
| music                | 737973f 依赖升级、6deab1e 统一签名、f2a5881 Windows 短路径 + 日志统一、2253f36 补齐 lint、c1dd03a versions.md、a72511b 签名材料入库    |
| snake                | 847851e 包名改 com.flutter.snake + 统一签名、19b8845 双流水线优化避长路径、9b4c2a6 依赖升级、0c2f16f versions.md、b7c516d 签名密钥入库 |
| tetris               | c54f066 统一长期签名、14b4c07 依赖升级、0547163 双流水线 Windows 与中文日志、c942031 versions.md、c1cccc8 签名材料入库                 |
