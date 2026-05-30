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

### v0.1.3 (当前)
- 修复 Bilibili 搜索 API 缺少 WBI 签名导致搜索失败
- 修复视频画质获取接口缺少 WBI 签名
- 修复 CI Windows 构建流程，确保生成 Windows Release
- 更新版本号到 0.1.3

### v0.1.2
- 重构优化存量代码，提升代码质量和健壮性
- 统一 API 实例管理，搜索和下载服务共享同一 BilibiliApi 实例
- 修复画质选择优先级逻辑 Bug
- 添加 CancelToken 支持，实现下载任务真正取消
- 改进 LogService 线程安全性和异常处理
- 增加测试覆盖（模型、工具类）

### v0.1.1
- 修复 intl 版本冲突导致 CI 构建失败
- 清理未使用的依赖项
- 补全 Windows runner 文件
- 移除缺失的字体和资源引用

### v0.1.0
- 初始版本：Bilibili 视频搜索、扫码登录、高清下载、下载管理、深色模式、日志系统

## 许可证

MIT License
