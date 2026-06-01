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

### v0.2.16 (当前)
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

### v0.2.12
- 修复 Issue #9 — CI 构建失败：
  - **移除 ffmpeg-kit-min 依赖**：该库已从 Maven 下架导致 CI Android 构建失败
  - **纯原生 MediaMuxer 合并**：移除所有 ffmpeg-kit 代码
  - **清理 ProGuard 规则**：移除已废弃的 ffmpeg-kit ProGuard 规则

### v0.2.11
- 修复 Issue #9：
  - **Android DASH 合并修复**：修复 MediaMuxer writeTrack 中 buffer.clear() 缺失导致的 MERGE_FAILED 问题
  - **Android ffmpeg-kit 回退**：引入 ffmpeg-kit-min 6.0-2，MediaMuxer 失败时自动回退到 ffmpeg 合并
  - **更详细的错误信息**：合并失败时同时展示 MediaMuxer 和 ffmpeg 的错误详情，便于问题定位

### v0.2.10
- 修复 Issue #8：
  - **Android DASH 视频/音频合并**：使用 Android MediaMuxer 原生 API 实现合并，无需外部 ffmpeg 依赖
  - **下载中任务支持删除**：下载中/排队中任务增加删除按钮，删除时自动取消下载

### v0.2.9
- 修复 CI 构建失败：
  - **Dart 编译错误修复** - home_page.dart SnackBar const 上下文引用实例方法，移除 const；video_detail_page.dart nullable BiliVideoFormat 添加 null-assert

### v0.2.8
- 修复 Issue #7 反馈（共 9 项）：
  - **DASH 下载进度卡 98%**：处理 total=-1 未知大小；进度 clamp 到 99，合并前显示 99%
  - **下载速度不准**：每个 part 独立速度跟踪，基于时间窗口增量计算
  - **失败/取消任务可删除**：下载管理页为所有非下载中任务提供删除按钮
  - **Windows 微软雅黑字体**：Windows 平台默认使用 Microsoft YaHei UI
  - **下载管理器搜索**：支持按视频名称搜索已添加的下载任务
  - **Cookie 持久化**：启动时预加载 SettingsProvider，确保登录状态不丢失
  - **登录状态检测**：启动时验证 Cookies 有效性，失效则提示重新登录
  - **详情页二次打开卡死**：clearDetail() 清除残留数据 + bvid 校验
  - **发布时间显示**：搜索列表、UP 主列表、详情页显示视频发布时间

### v0.2.7
- 修复 Issue #6 评论补充反馈：
  - **画质选择体验优化**：视频详情页新增显式 Dropdown + ChoiceChip + 当前画质提示，算法改为基于 quality int 的稳定优先级
  - **Windows 内置 ffmpeg**：GitHub Actions 构建时自动下载并打包 `ffmpeg.exe` / `ffprobe.exe` 到 release zip 同目录，开箱即用无需用户额外安装
  - **修复多个 `LateInitializationError`**：StorageService 引入 `_initFuture` 缓存解决并发竞态；main() 启动时预初始化 StorageService；NotificationService 增加平台守卫与全链路 try/catch
  - **规避 412 风控**：BilibiliApi 启动时主动访问 `www.bilibili.com` 获取 `buvid3` cookie 并附加到所有后续请求
  - **更友好的错误提示**：412 / -101(未登录) / -10403(大会员专享) 等错误转换为可读中文提示；下载层透传业务错误且不再无意义重试

### v0.2.6
- 修复 Issue #6（综合反馈 9 项）：
  - Windows DASH 下载自动调用系统 ffmpeg 合并视频/音频，未安装时保留双文件并明确提示
  - Android 下载到外部存储 `Movies/Bilibili`，可通过文件管理器/图库直接访问
  - UP 主搜索结果点击进入独立视频列表页，并支持继续进入视频详情
  - 已完成任务新增"打开所在目录"按钮（桌面端调用文件管理器定位文件）
  - 首选画质默认调整为 **4K**，画质选择优先级以用户首选画质为最优
  - 设置页展示日志目录路径，支持复制/打开
  - 显示已登录账号头像 + 用户名（调用 `/x/web-interface/nav` 接口）
  - 宽屏（>=900px）切换为 NavigationRail 主从布局，手机端保持底部导航

### v0.1.x - v0.2.5（历史版本合并）
- v0.1.0：初始版本 — Bilibili 视频搜索、扫码登录、高清下载、下载管理、深色模式、日志系统
- v0.1.1 ~ v0.1.3：CI 构建修复、Bilibili API WBI 签名、Windows Release 构建、重构优化
- v0.2.0 ~ v0.2.2：下载历史持久化、画质选择交互、下载速度实时显示、搜索类型切换、下载完成通知、Issue #2/#3 修复
- v0.2.3：重构优化（StorageService 单例、SearchPage 竞态、DASH CancelToken、长方法拆分、WBI 重试）
- v0.2.4：修复 Issue #4 — 显示已下载视频本地存储地址
- v0.2.5：修复 Issue #5 — 优先使用单文件格式下载，Android 下载文件存在性修复

## 许可证

MIT License
