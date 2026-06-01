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

- **框架**: Flutter 3.19+
- **语言**: Dart 3.2+
- **状态管理**: Provider
- **网络请求**: Dio
- **本地存储**: SharedPreferences
- **目标平台**: Android (minSdk 34, targetSdk 36), Windows 10+

## 快速开始

### 环境要求

- Flutter SDK 3.19+
- Dart SDK 3.2+
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

### v0.2.17 (当前)
- 修复 Issue #12（2 项反馈）：
  - **修复 Windows 下载管理批量清理/删除按钮**：改进 Provider 清除逻辑，使用 `List.from()` 创建新列表引用确保 UI 刷新，同步调用 service 层清理；排队中任务清除时先取消下载再删除
  - **修复 Android Media3 Transformer 合并失败**：移除错误的 `setVideoMimeType(video/mp4)` 调用（容器 MIME 类型不被接受），让 Media3 Transformer 自动检测输入格式并选择最优输出编码

### v0.2.16
- 修复 CI 编译错误（v0.2.15 遗留）：
  - **修复 bilibili_api.dart**：补充缺失的 `StorageService` import
  - **修复 download_service.dart**：修复 `num`/`int` 类型不匹配导致 Dart 编译失败
  - **CI 构建恢复**：确保 Android + Windows 构建通过

### v0.2.15
- 修复 Issue #10（5 项反馈）：
  - **断点续传**：app 重启后自动恢复未完成的下载任务，使用 HTTP Range 支持从断点继续下载
  - **合并超时增大**：Android 合并超时从 120s 增大到 10 小时（36000s）
  - **批量清理**：下载管理新增 PopupMenu 按状态批量清理任务（已完成/失败/已取消/排队中/全部）
  - **时间显示增强**：下载卡片显示已用时、预估剩余时间；已完成任务显示下载用时、合并用时、总用时
  - **Cookie 持久化改进**：buvid3 持久化缓存，减少每次启动的网络请求
- 修复 Issue #11：
  - **Media3 Transformer 无损合并**：使用 `setVideoMimeType` 启用转封装（passthrough）模式，避免重编码

### v0.2.14
- 修复 Issue #9 — Media3 Transformer 线程错误导致合并失败：
  - **Transformer 线程修复**：Transformer 必须在主线程（有 Looper）上创建和调用所有方法
  - **移除 Thread 包装**：改用回调模式 + Handler 超时，不再手动创建后台线程
  - **修复合并失败**：解决 "Media3 Transformer 必须在创建它的同一个线程上被访问" 错误

### v0.2.13
- 修复 Issue #9 — MediaMuxer 合并仍报 IllegalArgumentException：
  - **改用 Jetpack Media3 Transformer**：替换原生 MediaExtractor + MediaMuxer，使用 Composition + Transformer 方案
  - **异步合并**：后台线程执行合并，支持超时控制（120s）
  - **详细错误信息**：合并失败时返回 errorCode，便于定位

### v0.1.x - v0.2.12（历史版本合并）
- v0.1.0：初始版本 — Bilibili 视频搜索、扫码登录、高清下载、下载管理、深色模式、日志系统
- v0.1.1 ~ v0.1.3：CI 构建修复、Bilibili API WBI 签名、Windows Release 构建、重构优化
- v0.2.0 ~ v0.2.2：下载历史持久化、画质选择交互、下载速度实时显示、搜索类型切换、下载完成通知、Issue #2/#3 修复
- v0.2.3：重构优化（StorageService 单例、SearchPage 竞态、DASH CancelToken、长方法拆分、WBI 重试）
- v0.2.4：修复 Issue #4 — 显示已下载视频本地存储地址
- v0.2.5：修复 Issue #5 — 优先使用单文件格式下载
- v0.2.6：修复 Issue #6（综合反馈 9 项）— DASH 下载合并、Android 存储、UP 主列表、4K 画质、登录展示、宽屏布局等
- v0.2.7：修复 Issue #6 补充 — 画质选择优化、Windows 内置 ffmpeg、412 风控规避、LateInitializationError 修复
- v0.2.8：修复 Issue #7（9 项）— 进度卡 98%、速度计算、搜索过滤、Cookie 持久化、登录检测等
- v0.2.9：修复 CI 构建（Dart 编译错误）
- v0.2.10：修复 Issue #8 — Android MediaMuxer 合并、下载中任务删除
- v0.2.11：修复 Issue #9 — MediaMuxer buffer.clear() Bug、ffmpeg-kit 回退
- v0.2.12：修复 Issue #9（CI 构建失败）— 移除 ffmpeg-kit 依赖、原生 MediaMuxer

## 许可证

MIT License
