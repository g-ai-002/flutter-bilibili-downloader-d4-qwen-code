# 四项目配置差异对比

> 对比时间：2026-10-19
> 对比范围：pubspec.yaml 依赖、Android 构建配置、analysis_options（lint）、CI 工作流（GitHub + Gitea）、目录结构
> 项目清单：`flutter-bilibili-downloader-d4-qwen-code`（下称 bilibili）、`flutter-music`、`flutter-snake`、`flutter-tetris`
>
> **状态更新（2026-10-19，统一方案已落地）**：① 依赖对齐——music/snake/tetris 升级 shared_preferences 2.5.6、path_provider 2.1.6、window_manager 0.5.2；② 签名统一——三项目改用正式 keystore（debug/release 同签名，key.properties + jks 随仓库分发），旧安装需卸载重装；③ workflow 统一——以 bilibili 为模板中文化 + Windows 短路径 C:\w，changelog 全部排除 .gitea，snake/tetris 保留 audioplayers 补丁；④ music 补齐 11 条 lint 规则；⑤ snake namespace/applicationId 改为 com.flutter.snake；⑥ versions.md 机制（.build/query_all_versions.py 通用版）复制到三项目并生成清单。勘误：music 的 windows/ 目录仅 CMakeLists.txt 被 git 跟踪（其余文件不入库，CI 端由 flutter create 重建），第 1 节"已提交"表述据此修正。

## 0. 结论速览

构建环境层面四个项目**已高度统一**（AGP / Gradle / Kotlin / compileSdk / JDK / R8 策略完全一致），实际分叉集中在 5 处：

1. **基础依赖版本分叉**（3 个包）：`shared_preferences`、`path_provider`、`window_manager`，bilibili 领先一个版本
2. **签名策略不一致**：bilibili 用正式 keystore（debug/release 同签名），其余 3 个 release 用 debug.keystore
3. **GitHub workflow 演进不同步**：bilibili 已中文化 + Windows 短路径改造，其余 3 个是旧版英文模板
4. **music 的 lint 规则少 11 条**
5. **snake 的 namespace 还是 `com.example.*` 脚手架默认值**

## 1. 项目概览

| 项 | bilibili | music | snake | tetris |
|---|---|---|---|---|
| 应用类型 | Bilibili 下载器 | 本地音乐播放器 | 贪吃蛇 | 俄罗斯方块 |
| 版本号 | 0.4.31 | 0.3.46 | 0.3.1 | 0.6.0 |
| applicationId / namespace | com.bilibili.downloader | com.flutter.music | **com.example.flutter_snake** | com.flutter.tetris |
| windows/ 目录 | 无（CI 时 `flutter create` 生成） | **有（已提交）** | 无（CI 生成） | 无（CI 生成） |
| .metadata | **无** | 有 | 有 | 有 |
| 特有文件 | versions.md、.build/、.qwen/ | — | — | — |

## 2. Dart / Flutter 环境（完全一致，无需动）

| 配置 | 四项目统一值 |
|---|---|
| Dart SDK 约束 | `>=3.13.5 <4.0.0` |
| CI Flutter 版本 | `3.47.7`（workflow env `FLUTTER_VERSION`） |
| CI JDK | Temurin 21（workflow env `JAVA_VERSION`） |

## 3. pubspec.yaml 依赖对比

### 3.1 共有依赖的版本分叉 ⚠️

| 依赖 | bilibili | music | snake | tetris | 建议统一到 |
|---|---|---|---|---|---|
| provider | 6.1.5+1 | 6.1.5+1 | 6.1.5+1 | 6.1.5+1 | ✅ 已一致 |
| flutter_lints (dev) | 6.0.0 | 6.0.0 | 6.0.0 | 6.0.0 | ✅ 已一致 |
| shared_preferences | **2.5.6** | 2.5.5 | 2.5.5 | 2.5.5 | 2.5.6 |
| path_provider | **2.1.6** | 2.1.5 | 2.1.5 | 2.1.5 | 2.1.6 |
| window_manager | **0.5.2** | 0.5.1 | 0.5.1 | 0.5.1 | 0.5.2 |

### 3.2 各项目独有依赖（业务决定，不属于"基础依赖"）

| 项目 | 独有依赖 |
|---|---|
| bilibili | dio 5.11.1、intl 0.20.3、crypto 3.0.7、flutter_local_notifications 22.3.2、url_launcher 6.3.3、ffmpeg_kit_extended_flutter 0.6.2（原生库走 gh-proxy 下载） |
| music | path 1.9.1、just_audio 0.10.5、just_audio_windows 0.2.3、audio_service 0.18.18、audio_session 0.2.3、audio_metadata_reader 1.6.0、file_picker 10.3.10、permission_handler 12.0.3 |
| snake | path 1.9.1、audioplayers 6.5.1 |
| tetris | path 1.9.1、audioplayers 6.5.1 |

注：`path` 在 music/snake/tetris 均为 1.9.1，bilibili 未直接依赖（仅传递依赖）。

## 4. Android 构建配置

### 4.1 完全一致（无需动）

| 配置 | 四项目统一值 |
|---|---|
| AGP | 9.2.1（settings.gradle 插件声明） |
| Kotlin | 2.3.21（插件 + kotlin-stdlib） |
| Gradle | 9.5.1-all（华为云镜像 distributionUrl） |
| compileSdk / targetSdk / minSdk | 37 / 37 / 35 |
| NDK | 30.0.16248370 |
| Java 兼容性 | VERSION_21 + jvmTarget 21 |
| coreLibraryDesugaring | 2.1.5（启用） |
| ABI | 仅 arm64-v8a |
| R8 / 资源收缩 | `minifyEnabled false` + `shrinkResources false`（全关，无 proguard 规则） |
| gradle.properties | -Xmx4G、useAndroidX、newDsl=false、builtInKotlin=false、kotlin.incremental=false |
| Maven 镜像 | `USE_ALIYUN_MAVEN` 条件启用阿里云镜像（settings/build.gradle + `android/gradle/init-aliyun-mirror.gradle`，4 个项目文件均存在） |

### 4.2 差异

| 配置 | bilibili | music / snake / tetris |
|---|---|---|
| 签名 | `key.properties` + `bilibili-downloader.jks` 正式 keystore，**debug 与 release 同签名** | release 用 `debug.keystore`（Android 默认调试签名） |
| namespace | 已定制 | music/tetris 已定制；**snake 仍是 `com.example.flutter_snake`** |

## 5. analysis_options.yaml（lint）

- bilibili / snake / tetris：**完全一致**，flutter_lints 基础上启用 14 条规则（require_trailing_commas、prefer_final_locals、prefer_single_quotes 等）
- music：**仅 3 条**（prefer_const_constructors、prefer_const_declarations、avoid_print: false），缺其余 11 条

## 6. CI 工作流对比

四项目均为双轨制：`.github/workflows/build.yml`（GitHub Actions）+ `.gitea/workflows/build.yml`（Gitea Actions，自托管 runner），触发方式（push tag `v*` + workflow_dispatch）、产物命名（`{仓库名}-{版本}-android-aarch64.apk` / `-windows-x86_64.zip`）、job 流水线（metadata → test → build-android ∥ build-windows → release）完全一致。

### 6.1 GitHub Actions 差异

| 差异点 | bilibili | music | snake | tetris |
|---|---|---|---|---|
| 工作流语言 | **中文 + emoji**（🚀 构建与发布） | 英文（Build and Release） | 英文 | 英文 |
| Windows 构建方式 | **复制到短路径 `C:\w`**（`cp -a`，规避长路径/ffmpeg-kit 问题），全程 bash | 直接在工作区构建，pwsh | 同 music | 同 music |
| ZIP 打包 | pwsh `Compress-Archive` | pwsh `Compress-Archive` | pwsh `Compress-Archive` | pwsh `Compress-Archive` |
| ffmpeg-kit 失败日志导出 | **有**（failure 时导出 hooks stdout/stderr/DLL 落点） | 无 | 无 | 无 |
| audioplayers 编译补丁 | 无 | 无 | **有**（CMakeLists.txt 注入 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`，pwsh 版） | **有**（同左） |
| release notes 排除目录 | docs、.github | docs、.github | docs、.github | docs、.github、**.gitea** ✅ 更完整 |

共同点：`subosito/flutter-action@v2`（3.47.7）+ `setup-java@v5`（temurin 21，gradle cache）；action 版本统一 checkout@v6 / upload-artifact@v7（retention 1 天）/ download-artifact@v8 / softprops/action-gh-release@v3；prerelease 自动识别 `-rc`/`-beta`。

### 6.2 Gitea Actions 差异

四项目 Gitea 版结构一致：`ubuntu-flutter` / `windows-flutter` 自托管 runner（预装 Flutter/JDK，无 setup 步骤）、build job 30 分钟超时、Android 构建前做环境诊断（环境变量 + flutter doctor + storage.flutter-io.cn 连通性）并部署 `init-aliyun-mirror.gradle` 到 `~/.gradle/init.d`、release 用 `GITEA_TOKEN` + curl 直调 Gitea API 逐文件上传（区别于 GitHub 的 softprops action）、changelog 均排除 docs/.github/.gitea。

| 差异点 | bilibili | music / snake / tetris |
|---|---|---|
| Windows 构建方式 | **复制到短路径 `C:\w`**（defaults working-directory） | 直接在工作区构建 |
| ZIP 打包 | pwsh `Compress-Archive` | bash `tar.exe -a -cf` |
| audioplayers 编译补丁 | 无 | snake/tetris 有（bash sed 版）；music 无 |
| Windows 诊断输出 | Flutter 版本 + doctor + PUB_HOSTED_URL 等 | `id` + Flutter 版本 + doctor |

## 7. 统一建议（按优先级）

1. **升级基础依赖**（低风险，改动最小）：music/snake/tetris 三个项目把 `shared_preferences → 2.5.6`、`path_provider → 2.1.6`、`window_manager → 0.5.2`，对齐 bilibili。升级后各跑一次 `flutter pub get` + CI 出包验证即可。
2. **补齐 music 的 lint 规则**：直接复制 bilibili/snake/tetris 的 `analysis_options.yaml`，先本地 `flutter analyze` 清一遍存量告警。
3. **以 bilibili 的 workflow 为基准模板同步其余 3 个项目**：中文名称/日志、Windows 短路径复制是 bilibili 最近踩坑后的演进（见提交 2890516、b1af1de）；同步时保留 snake/tetris 的 audioplayers 补丁步骤，并采纳 tetris 的 `exclude .gitea`（GitHub 版 changelog 不应把 Gitea 工作流变更写进 GitHub release notes）。
4. **snake namespace 定制**：`com.example.flutter_snake` → 如 `com.flutter.snake`。注意这会改变 applicationId，已安装用户需卸载重装（游戏类影响小，但建议趁早改）。
5. **签名策略（可选决策）**：目前仅 bilibili 有正式签名。若其余 3 个也长期分发，建议各自生成 keystore（或共用一个，applicationId 不同不冲突），参考 bilibili 的 `key.properties` + jks 方案；若仅自用/无所谓升级覆盖安装，维持 debug 签名也可接受。
6. **windows/ 目录策略（可选决策）**：music 提交了 windows/ 目录，其余 3 个 CI 运行时 `flutter create` 生成。CI 生成的好处是 Flutter 升级时无需手动维护平台文件；music 提交可能是为了自定义窗口逻辑。统一为"CI 生成"维护成本最低。
7. **杂项**：bilibili 缺 `.metadata`（官方工具元数据，可由 `flutter create .` 补回，非必需）；GitHub workflow 中 build-windows 的 `flutter create` 与 `pub get` 顺序在 bilibili（先 get 后 create）与其余 3 个（先 create 后 get）不同，功能等价，统一模板时顺手对齐即可。

## 8. 差异之外的提醒

- `audioplayers 6.5.1`（snake/tetris）的 CMake 补丁是**平台专属 workaround**，统一基础依赖时不要顺手升级 audioplayers 而删除补丁，除非确认新版已修复。
- `ffmpeg_kit_extended_flutter`（bilibili）原生库走 gh-proxy，是该网络环境下的特例配置，其他项目如引入 ffmpeg 相关需求可参考。
- 四项目 CI 的 Flutter/JDK/AGP/Kotlin/Gradle 完全同版本，**工具链层面不存在分叉**，统一工作只涉及上述 5 项。
