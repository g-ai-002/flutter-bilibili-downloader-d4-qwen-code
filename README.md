# Bilibili 视频下载器

基于 Flutter 开发的跨平台 Bilibili 视频下载工具，支持 Android 和 Windows 平台。

## 功能特性

- 🔍 **视频搜索** - 搜索 Bilibili 视频和 UP 主
- 📋 **视频详情** - 查看视频分集、画质信息
- 📱 **扫码登录** - Bilibili 扫码登录，获取更高画质
- ⬇️ **高清下载** - 优先下载最高画质视频
- 📊 **下载管理** - 实时进度、暂停、重试、取消
- 🌙 **深色模式** - 支持深色/浅色主题切换
- 📝 **日志系统** - 完整的应用日志记录

## 技术栈

- **框架**: Flutter 3.44+
- **语言**: Dart 3.10+
- **状态管理**: Provider
- **网络请求**: Dio
- **本地存储**: SharedPreferences
- **目标平台**: Android (minSdk 34, targetSdk 36), Windows 10+

## 快速开始

### 环境要求

- Flutter SDK 3.44+
- Dart SDK 3.10+
- Android Studio (Android 构建)
- Visual Studio 2022 (Windows 构建)

### 构建

```bash
# 获取依赖
flutter pub get

# Android APK
flutter build apk --release

# Windows
flutter build windows --release
```

## 版本历史

### v0.2.34 (当前)
- 修复 CI Windows 构建失败：
  - **移除 ffmpeg_kit_extended_flutter**：该包原生资源在 Windows 构建时失败，导致 CI 无法通过
  - **Android 改用原生合并**：使用 MediaExtractor + MediaMuxer + MethodChannel 实现无损视频/音频合并，零外部依赖
  - **桌面端保持 ffmpeg**：Windows 继续使用打包的系统 ffmpeg 进行合并
- 修复 Issue #13 — Android 应用图标与名称：
  - **图标美化**：B站粉色圆角背景 + TV下载箭头图标，更美观
  - **桌面名称**：显式设置 label 和 roundIcon，确保应用名在启动器显示

### v0.2.17
- 修复 Issue #12（2 项反馈）：
  - **修复 Windows 下载管理批量清理/删除按钮**：改进 Provider 清除逻辑，使用 List.from() 创建新列表引用确保 UI 刷新，同步调用 service 层清理
  - **修复 Android Media3 Transformer 合并失败**：移除错误的 setVideoMimeType 调用，让 Media3 Transformer 自动检测输入格式

### v0.2.16
- 修复 CI 编译错误（v0.2.15 遗留）：
  - **修复 bilibili_api.dart**：补充缺失的 StorageService import
  - **修复 download_service.dart**：修复 num/int 类型不匹配导致 Dart 编译失败

### v0.2.15
- 修复 Issue #10（5 项反馈）：
  - **断点续传**：app 重启后自动恢复未完成的下载任务，使用 HTTP Range 从断点继续
  - **合并超时增大**：Android 合并超时从 120s 增大到 10 小时
  - **批量清理**：下载管理新增 PopupMenu 按状态批量清理任务
  - **时间显示增强**：下载卡片显示已用时、预估剩余时间、合并用时等
  - **Cookie 持久化改进**：buvid3 持久化缓存
- 修复 Issue #11：**Media3 Transformer 无损合并** — 使用 setVideoMimeType 启用转封装模式

### v0.1.x - v0.2.14（历史版本合并）
- v0.1.0：初始版本 — Bilibili 视频搜索、扫码登录、高清下载、下载管理、深色模式、日志系统
- v0.1.1 ~ v0.1.3：CI 构建修复、WBI 签名、Windows Release 构建、重构优化
- v0.2.0 ~ v0.2.2：下载历史持久化、画质选择、下载速度显示、搜索类型切换、通知、Issue #2/#3 修复
- v0.2.3：重构优化（StorageService 单例、SearchPage 竞态、DASH CancelToken、长方法拆分、WBI 重试）
- v0.2.4：修复 Issue #4 — 显示已下载视频本地存储地址
- v0.2.5：修复 Issue #5 — 优先使用单文件格式下载
- v0.2.6：修复 Issue #6（9 项）— DASH 合并、Android 存储、UP 主列表、4K 画质、宽屏布局等
- v0.2.7：修复 Issue #6 补充 — 画质优化、内置 ffmpeg、412 风控、LateInitializationError 修复
- v0.2.8：修复 Issue #7（9 项）— 进度卡 98%、速度计算、搜索过滤、Cookie 持久化、登录检测
- v0.2.9：修复 CI 构建（Dart 编译错误）
- v0.2.10：修复 Issue #8 — Android MediaMuxer 合并、下载中任务删除
- v0.2.11：修复 Issue #9 — MediaMuxer buffer.clear()、ffmpeg-kit 回退
- v0.2.12：修复 Issue #9（CI）— 移除 ffmpeg-kit、原生 MediaMuxer
- v0.2.13：修复 Issue #9 — 改用 Jetpack Media3 Transformer
- v0.2.14：修复 Issue #9 — Media3 Transformer 线程修复

## 许可证

MIT License
