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

### v0.2.7 (当前)
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

### v0.2.5
- 修复 Issue #5：Android 上下载的视频文件不存在
- 优先使用单文件格式下载（fnval=16），确保下载文件为含音视频的单文件
- DASH 回退时 filePath 指向实际存在的视频文件

### v0.2.4
- 修复 Issue #4：显示已下载视频的本地存储地址
- 下载页面已完成任务卡片显示文件存储路径，支持一键复制
- 设置页面增加下载目录信息展示，支持复制路径
- 优化 Android 存储权限（minSdk 34 使用应用专属存储无需额外权限）

### v0.2.3
- 重构优化存量代码，提升代码质量和健壮性
- 修复 StorageService 单例模式，避免重复初始化
- 修复 SearchPage 搜索历史竞态条件
- 合并 DownloadService 重复代码，拆分长方法
- 修复 DASH 下载 CancelToken 管理
- 优化 BilibiliApi WBI 密钥获取重试机制
- 优化 VideoDetailPage 画质选择逻辑

### v0.1.x - v0.2.2（历史版本合并）
- 初始版本：Bilibili 视频搜索、扫码登录、高清下载、下载管理、深色模式、日志系统
- CI 构建修复、Bilibili API WBI 签名、Windows Release 构建
- 重构优化：统一 API 实例、画质选择 Bug、CancelToken、LogService 线程安全
- 下载历史持久化、画质选择交互、下载速度实时显示、搜索类型切换、下载完成通知
- 修复 Issue #2 下载进度始终为 0（DownloadJob 缺少 cid）
- 修复 Issue #3 DASH 下载进度回退、速度计算异常

## 许可证

MIT License
