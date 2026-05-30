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

### v0.2.2 (当前)
- 修复 DASH 下载进度回退问题（Issue #3）
- 优化 DASH 下载流程，合并视频轨和音频轨的进度计算
- 修复下载速度计算在音频轨下载时重置的问题

### v0.2.1
- 修复下载进度始终为 0 的问题（Issue #2）
- DownloadJob 模型新增 cid 字段，修复播放地址获取失败 Bug

### v0.2.0
- 下载历史持久化，重启后可查看历史下载记录
- 画质选择交互优化，用户可在视频详情页点击选择不同画质
- 下载速度实时显示，在下载卡片中实时更新下载速度
- 搜索类型切换，支持在视频搜索和UP主搜索之间切换
- 下载完成通知，下载完成后显示通知提示

### v0.1.3
- 修复 Bilibili 搜索 API 缺少 WBI 签名导致搜索失败
- 修复视频画质获取接口缺少 WBI 签名
- 修复 CI Windows 构建流程，确保生成 Windows Release

### v0.1.2 ~ v0.1.0
- 重构优化存量代码，提升代码质量和健壮性
- 修复 CI 构建失败问题，补全缺失文件
- 初始版本：Bilibili 视频搜索、扫码登录、高清下载、下载管理、深色模式、日志系统

## 许可证

MIT License
