# Bilibili 视频下载器

基于 Flutter 开发的跨平台 Bilibili 视频下载工具，支持 Android 和 Windows 平台。

## 功能特性

- 🔍 **视频搜索** - 搜索 Bilibili 视频和 UP 主，支持 Tab 栏切换搜索类型
- 📋 **视频详情** - 查看视频分集、画质、时长信息
- 📱 **扫码登录** - Bilibili 扫码登录，获取更高画质
- ⬇️ **高清下载** - 优先下载最高画质视频（最高支持 4K）
- 📊 **下载管理** - 实时进度、断点续传、视频时长/分辨率/编码元数据显示
- 🌙 **深色模式** - 支持深色/浅色主题切换（B 站粉色主题）
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

### v0.4.10 (当前开发版本)
- 下载完成视频卡片增加视频时长显示
- 搜索类型切换（视频/UP主）从搜索框内移出，改为导航栏内 Tab 栏
- Tab 栏随滚动隐藏/显示

### v0.4.9
- CI 构建修复及 Gradle 配置优化

### v0.4.8
- 修复 search_page 括号错误

### v0.4.7
- UI 灰底调浅、搜索类型下拉合并到搜索框

### v0.4.1
- 主题色修正为 B 站粉 (#FB7299)

### v0.4.0
- UI 国内审美改造 — 去阴影、灰底白卡、0.5px 极细线、去水波纹
- 底部导航切换为 BottomNavigationBar
- 宽屏 NavigationRail 去背景色
- 输入框 0.5px 细边框

### v0.2.41
- Windows/Android 双平台依赖分离 — Windows 原生 ffmpeg，Android ffmpeg_kit_extended_flutter
- 平台特定 ffmpeg 实现分离

### v0.2.36
- Windows DASH 合并切换到 ffmpeg_kit_extended_flutter（后于 v0.2.41 回退）

### v0.2.34
- 修复 CI Windows 构建失败（移除 ffmpeg_kit_extended_flutter）
- 修复 Issue #13 — Android 应用图标美化 + 桌面显示应用名称

### v0.2.17
- 修复 Issue #12 — Windows 批量清理按钮 + Android Media3 Transformer 合并失败

### v0.2.16
- 修复 v0.2.15 遗留 CI 编译错误

### v0.2.15
- 修复 Issue #10（5 项）— 断点续传、合并超时、批量清理、时间显示、Cookie 持久化
- 修复 Issue #11 — Media3 Transformer 无损合并

### v0.2.14
- 修复 Issue #9 — Media3 Transformer 线程错误导致合并失败

### v0.2.13
- 修复 Issue #9 — 改用 Jetpack Media3 Transformer 替换原生 MediaMuxer

### v0.2.12
- 修复 Issue #9 — 移除已停更的 ffmpeg-kit，完善原生 MediaMuxer 合并

### v0.2.11
- 修复 Issue #9 — MediaMuxer buffer.clear() Bug + ffmpeg-kit 回退

### v0.2.10
- 修复 Issue #8 — Android MediaMuxer 合并 + 下载中任务可删除

### v0.2.9
- 修复 CI 构建失败（v0.2.8 遗留 Dart 编译错误）

### v0.2.8
- 修复 Issue #7（9 项）— 进度卡 98%、速度计算、搜索过滤、Cookie 持久化、登录检测等

### v0.2.7
- 修复 Issue #6 补充 — 画质优化、内置 ffmpeg、412 风控、LateInitializationError 修复

### v0.2.6
- 修复 Issue #6（9 项）— DASH 合并、Android 存储、UP 主列表、4K 画质、宽屏布局等

### v0.2.5
- 修复 Issue #5 — 优先使用单文件格式下载，修复 Android 视频文件不存在

### v0.2.4
- 修复 Issue #4 — 显示已下载视频本地存储地址，支持复制路径

### v0.2.3
- 重构优化 — StorageService 单例、SearchPage 竞态、DASH CancelToken、长方法拆分、WBI 重试

### v0.2.2
- 修复 Issue #3 — DASH 下载进度回退、速度计算异常，统一进度合并

### v0.2.1
- 修复 Issue #2 — DownloadJob 缺少 cid 导致下载进度始终为 0

### v0.2.0
- 下载历史持久化、画质选择交互、下载速度实时显示、搜索类型切换、下载完成通知

### v0.1.3
- 修复 Issue #1 — WBI 签名缺失导致搜索失败

### v0.1.2
- 重构优化 — 统一 API 实例、CancelToken、LogService 线程安全、测试覆盖

### v0.1.1
- 修复 CI 构建 — intl 冲突、Android Gradle、Dart 编译错误

### v0.1.0
- 初始版本 — 搜索、登录、下载管理、深色模式、Material Design

## 许可证

MIT License
