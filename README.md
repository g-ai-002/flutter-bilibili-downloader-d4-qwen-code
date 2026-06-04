# Bilibili 视频下载器

基于 Flutter 开发的跨平台 Bilibili 视频下载工具，支持 Android 和 Windows 平台。

## 功能特性

- 🔍 **视频搜索** - 搜索 Bilibili 视频和 UP 主，支持 Tab 栏切换和左右滑动切换
- 📋 **视频详情** - 查看视频分集、画质、时长、UP 主信息
- 📱 **扫码登录** - Bilibili 扫码登录，获取更高画质
- ⬇️ **高清下载** - 优先下载最高画质视频（最高支持 4K），支持分集批量下载
- 📊 **下载管理** - 实时进度、断点续传、下载任务搜索和批量清理
- 🏷️ **元数据显示** - 下载完成后展示时长、大小、分辨率、帧率、编码等元数据
- 🎨 **搜索历史** - 自动保存搜索关键词，支持清空和逐条删除
- 🌙 **深色模式** - 支持深色/浅色主题切换（B 站粉色主题）
- 📝 **日志系统** - 完整的应用日志记录，支持查看和分享日志
- 🖥️ **双平台** - Android + Windows 原生支持，宽屏自适应 NavigationRail 布局

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

### v0.4.21 (当前版本)
- 下载卡片布局重构 — 状态图标+文本移至视频标题上方
- 下载卡片新增 UP 主名称和发布时间（标题下方）
- 已完成任务元数据添加中文标签（时长/大小/分辨率/帧率）
- DownloadJob 模型扩展 uploader/pubdate 字段

### v0.4.20
- 搜索页 Tab 栏高度缩小约 1/3（46→32px），字体 13→12
- 消除搜索历史/搜索结果与导航栏之间的空白区域
- 所有列表显式设置 padding: zero

### v0.4.19
- 搜索页重构 — NestedScrollView 替换为 Column+Expanded 固定布局
- 彻底解决顶部导航栏+Tab 栏上下滑动时的抖动问题
- 修复内容列表滚动卡顿，流畅度对齐 UP 主页面
- 移除 _TabBarDelegate 和 ClampingScrollPhysics

### v0.4.18
- 统一界面底色 + 搜索页固定导航栏禁用弹性滚动

### v0.4.17
- 搜索页导航栏/TabBar 常驻显示
- 搜索卡片切换为横线分割布局
- 视频详情页简介完整显示
- 搜索框为空时优先显示搜索历史

### v0.4.16
- 版本号升级至 0.4.16 + 样式微调

### v0.4.15
- TabBar 高度紧贴内容消除留白
- 修复滑动切换 Tab 时搜索历史闪烁
- TabBar 指示器颜色修正、内容间距减小
- 搜索页支持左右滑动切换

### v0.4.14
- 删除冗余的 pubspec_android.yaml（默认已是 Android）
- 版本升至 0.4.14

### v0.4.13
- 添加 JDK 21 修复 Android 构建

### v0.4.12
- 导航栏 UI 精细化 — 0.5px 分隔线、降低导航栏高度、搜索框去边框浅灰底色
- 搜索框底色改用 surfaceVariant
- 搜索框圆角调整至 8

### v0.4.11
- 梳理版本历史，plan.md 去重按版本号排序，README.md 补全缺失版本

## 许可证

MIT License
