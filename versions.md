# 开源软件版本清单

> 本文件由脚本 `.build/query_all_versions.py` 自动生成，数据来源：Flutter 依赖为
> [pub.dev API](https://pub.dev/api/packages/)，Android 构建链为
> [Google Maven](https://dl.google.com/dl/android/maven2/) /
> [Maven Central](https://repo1.maven.org/maven2/) /
> [Gradle 版本服务](https://services.gradle.org/versions/all)。
>
> **列说明**：
> - **当前版本**：Flutter 依赖取自 `pubspec.yaml`；构建链取自 `android/` 下的
>   Gradle 配置
> - **MAJOR 最新版本**：最新大版本线的最新稳定版
>   （跨大版本升级，可能含破坏式变更）
> - **MINOR 最新版本**：当前大版本线内的最新稳定版（同大版本升级，通常向后兼容）
> - **PATCH 最新版本**：当前大版本.中版本线内的最新补丁版（仅 bug 修复）
>
> 标注 `(已是最新)` 表示当前版本已是该版本线最新。预发布版
> （alpha / beta / rc / dev / milestone）不计入最新版本。
>
> 刷新方式：运行 `python .build/query_all_versions.py` 重新生成

## 项目基础信息

| 项目                                      | 版本                               |
|-------------------------------------------|------------------------------------|
| 应用版本 (`pubspec.yaml`)                 | 0.4.34                             |
| 应用内版本号 (`lib/utils/constants.dart`) | 0.4.34                             |
| Flutter SDK（CI 固定版本）                | 3.47.7                             |
| Dart SDK 约束                             | >=3.13.5 <4.0.0                    |
| compileSdk / targetSdk                    | 37 / 37                            |
| minSdk                                    | 35                                 |
| NDK                                       | 30.0.16248370                      |
| Java (source/target)                      | 21                                 |
| 目标平台                                  | Android (arm64-v8a)、Windows (x64) |

发布产物：Android APK（`android-arm64`）与 Windows ZIP（`windows-x86_64`），由 GitHub Actions 与 Gitea Actions 双流水线构建。

---

## 1. Flutter 运行时依赖

| 组件                                                        | 当前版本  | MAJOR 最新版本       | MINOR 最新版本       | PATCH 最新版本       | 引用文件       | 说明                          | 类型         |
|-------------------------------------------------------------|-----------|----------------------|----------------------|----------------------|----------------|-------------------------------|--------------|
| Provider (`provider`)                                       | `6.1.5+1` | `6.1.5+1` (已是最新) | `6.1.5+1` (已是最新) | `6.1.5+1` (已是最新) | `pubspec.yaml` | 状态管理                      | dependencies |
| Dio (`dio`)                                                 | `5.11.1`  | `5.11.1` (已是最新)  | `5.11.1` (已是最新)  | `5.11.1` (已是最新)  | `pubspec.yaml` | HTTP 客户端                   | dependencies |
| Shared Preferences (`shared_preferences`)                   | `2.5.6`   | `2.5.6` (已是最新)   | `2.5.6` (已是最新)   | `2.5.6` (已是最新)   | `pubspec.yaml` | 键值本地存储                  | dependencies |
| Path Provider (`path_provider`)                             | `2.1.6`   | `2.1.6` (已是最新)   | `2.1.6` (已是最新)   | `2.1.6` (已是最新)   | `pubspec.yaml` | 平台目录定位                  | dependencies |
| Intl (`intl`)                                               | `0.20.3`  | `0.20.3` (已是最新)  | `0.20.3` (已是最新)  | `0.20.3` (已是最新)  | `pubspec.yaml` | 国际化与日期格式化            | dependencies |
| Crypto (`crypto`)                                           | `3.0.7`   | `3.0.7` (已是最新)   | `3.0.7` (已是最新)   | `3.0.7` (已是最新)   | `pubspec.yaml` | 哈希与加密算法                | dependencies |
| Flutter Local Notifications (`flutter_local_notifications`) | `22.3.2`  | `22.3.2` (已是最新)  | `22.3.2` (已是最新)  | `22.3.2` (已是最新)  | `pubspec.yaml` | 本地通知                      | dependencies |
| URL Launcher (`url_launcher`)                               | `6.3.3`   | `6.3.3` (已是最新)   | `6.3.3` (已是最新)   | `6.3.3` (已是最新)   | `pubspec.yaml` | 外部链接与应用唤起            | dependencies |
| FFmpeg Kit Extended Flutter (`ffmpeg_kit_extended_flutter`) | `0.6.2`   | `1.0.0`              | `0.6.2` (已是最新)   | `0.6.2` (已是最新)   | `pubspec.yaml` | 音视频处理（FFmpeg Kit 扩展） | dependencies |
| Window Manager (`window_manager`)                           | `0.5.2`   | `0.5.2` (已是最新)   | `0.5.2` (已是最新)   | `0.5.2` (已是最新)   | `pubspec.yaml` | 桌面窗口管理（Windows）       | dependencies |

## 2. Flutter 开发依赖

| 组件                            | 当前版本 | MAJOR 最新版本     | MINOR 最新版本     | PATCH 最新版本     | 引用文件       | 说明             | 类型             |
|---------------------------------|----------|--------------------|--------------------|--------------------|----------------|------------------|------------------|
| Flutter Lints (`flutter_lints`) | `6.0.0`  | `6.0.0` (已是最新) | `6.0.0` (已是最新) | `6.0.0` (已是最新) | `pubspec.yaml` | 官方 lint 规则集 | dev_dependencies |

## 3. Android 构建链

| 组件                  | 当前版本 | MAJOR 最新版本     | MINOR 最新版本     | PATCH 最新版本      | 引用文件                                           | 说明                  |
|-----------------------|----------|--------------------|--------------------|---------------------|----------------------------------------------------|-----------------------|
| Gradle                | `9.8.2`  | `9.8.2` (已是最新) | `9.8.2` (已是最新) | `9.8.2` (已是最新)  | `android/gradle/wrapper/gradle-wrapper.properties` | Gradle Wrapper 分发包 |
| Android Gradle Plugin | `9.4.1`  | `9.4.1` (已是最新) | `9.4.1` (已是最新) | `9.4.1` (已是最新)  | `android/settings.gradle`                          | Android 构建插件      |
| Kotlin Gradle Plugin  | `2.4.21` | `2.4.21` (已是最新)| `2.4.21` (已是最新)| `2.4.21` (已是最新) | `android/settings.gradle`                          | Kotlin 编译插件       |
| Kotlin Stdlib         | `2.4.21` | `2.4.21` (已是最新)| `2.4.21` (已是最新)| `2.4.21` (已是最新) | `android/app/build.gradle`                         | Kotlin 标准库         |
| Desugar JDK Libs      | `2.1.5`  | `2.1.5` (已是最新) | `2.1.5` (已是最新) | `2.1.5` (已是最新)  | `android/app/build.gradle`                         | Java 8+ API 脱糖支持  |

## 4. CI 与外部工具

| 组件                                                                     | 当前版本 | 引用文件                                                     | 说明                                                                             |
|--------------------------------------------------------------------------|----------|--------------------------------------------------------------|----------------------------------------------------------------------------------|
| ffmpeg-kit Windows 原生库 (`bundle-base-windows-x86_64-shared-lgpl.zip`) | `0.11.1` | `pubspec.yaml`                                               | Windows 产物内置的 libffmpegkit.dll（构建期由 ffmpeg_kit 钩子下载 → code asset） |
| actions/checkout                                                         | `v6`     | `.github/workflows/build.yml` / `.gitea/workflows/build.yml` | 检出仓库代码                                                                     |
| subosito/flutter-action                                                  | `v2`     | `.github/workflows/build.yml`                                | 安装指定版本 Flutter SDK                                                         |
| actions/setup-java                                                       | `v5`     | `.github/workflows/build.yml`                                | 安装 JDK（Temurin）                                                              |
| actions/upload-artifact                                                  | `v7`     | `.github/workflows/build.yml`                                | 上传构建产物（GitHub）                                                           |
| actions/download-artifact                                                | `v8`     | `.github/workflows/build.yml`                                | 下载构建产物（GitHub）                                                           |
| softprops/action-gh-release                                              | `v3`     | `.github/workflows/build.yml`                                | 创建 GitHub Release                                                              |
| actions/gitea-upload-artifact                                            | `v4`     | `.gitea/workflows/build.yml`                                 | 上传构建产物（Gitea）                                                            |
| actions/gitea-download-artifact                                          | `v8`     | `.gitea/workflows/build.yml`                                 | 下载构建产物（Gitea）                                                            |

---

## 如何刷新本文档

运行脚本重新查询 pub.dev / Google Maven / Maven Central / Gradle 版本服务并生成：

```bash
python .build/query_all_versions.py
```

也可以直接访问对应元数据：

- Flutter 依赖：`https://pub.dev/api/packages/<package>`
- Android Gradle Plugin / desugar_jdk_libs：[Google Maven](https://dl.google.com/dl/android/maven2/) 的 `maven-metadata.xml`
- Kotlin：[Maven Central](https://repo1.maven.org/maven2/) 的 `maven-metadata.xml`
- Gradle：`https://services.gradle.org/versions/all`