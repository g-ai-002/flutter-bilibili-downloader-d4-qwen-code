# Bilibili 视频下载器 - Flutter 版本

## 项目规划

### 长期目标
- 构建一个功能完善的 Bilibili 视频下载 Flutter 应用
- 支持 Android 和 Windows 双平台
- 提供精美的 Material Design 界面
- 支持扫码登录、视频搜索、高清下载

### 中期目标
- [ ] 实现 Bilibili API 完整封装
- [ ] 实现多任务下载管理
- [ ] 实现下载进度实时显示
- [ ] 实现本地下载历史管理

### 短期目标 (v0.1.0)
- [x] 项目基础结构搭建
- [x] Bilibili API 客户端 (搜索、详情、WBI 签名)
- [x] Bilibili 扫码登录
- [x] 数据模型定义
- [x] 状态管理 (Provider)
- [x] 下载服务
- [x] 本地存储服务
- [x] 日志系统
- [x] UI 界面 (首页、搜索、详情、下载管理、设置)
- [x] GitHub Actions 工作流 (Android + Windows)
- [x] 文档完善

### v0.1.1 (PATCH)
- [x] 修复 intl 版本冲突导致 CI 构建失败
- [x] 修复 assets 目录和字体文件缺失
- [x] 补全 Windows runner 文件（由 CI 自动生成）
- [x] 清理未使用的依赖
- [x] 修复 Android Gradle 构建（改用新版 plugin 声明方式）
- [x] 修复 Dart 编译错误 (retryCount, surfaceContainerHighest, cookies, 图标)
- [x] 修复 Android 资源链接失败（移除缺失图标引用）
- [x] 更新版本号到 0.1.1
- [x] CI 构建通过 ✅

### v0.1.2 (当前版本 - PATCH)
- [x] 统一 API 实例管理，避免创建重复实例
- [x] 修复画质选择优先级逻辑 Bug
- [x] 改进 DownloadService 空对象模式，使用 indexWhere 替代 firstWhere
- [x] 添加 CancelToken 支持，实现下载任务真正取消
- [x] 移除冗余代码（SearchPage 多余 setState）
- [x] 改进 LogService 线程安全性和异常处理
- [x] 移除未使用的 dart:math 导入
- [x] 修复搜索历史重复项问题
- [x] 版本号统一管理（settings_page 引用 AppConstants.version）
- [x] 增加测试覆盖（模型、工具类）
- [x] 更新版本号到 0.1.2

### v0.1.3 (当前版本 - PATCH)
- [ ] 修复 Bilibili 搜索 API 缺少 WBI 签名导致搜索失败
- [ ] 修复视频画质获取接口缺少 WBI 签名
- [ ] 修复 CI Windows 构建流程，确保生成 Windows Release
- [ ] 更新版本号到 0.1.3

---

## 版本历史

### v0.1.3 (当前版本)
- **状态**: 开发中 🔄
- **目标**: 修复 Issue #1 问题（Windows Release 缺失、Android 搜索失败）
- **修复**:
  - 修复 Bilibili 搜索 API 缺少 WBI 签名导致搜索失败
  - 修复视频画质获取接口缺少 WBI 签名
  - 修复 CI Windows 构建流程，确保生成 Windows Release
  - 更新版本号到 0.1.3

### v0.1.2
- **状态**: 已发布 ✅
- **目标**: 重构优化存量代码，提升代码质量和健壮性
- **重构**:
  - 统一 API 实例管理，搜索和下载服务共享同一 BilibiliApi 实例
  - 修复画质选择优先级逻辑 Bug（优先级选择后被无条件覆盖）
  - 改进 DownloadService 空对象模式，使用 indexWhere 替代 firstWhere
  - 添加 CancelToken 支持，实现下载任务真正取消
  - 移除冗余代码（SearchPage 多余 setState）
  - 改进 LogService 线程安全性和异常处理
  - 移除未使用的 dart:math 导入
  - 修复搜索历史重复项问题
  - 版本号统一管理（settings_page 引用 AppConstants.version）
  - 增加测试覆盖（模型、工具类）

### v0.1.1
- **状态**: 已发布 ✅
- **目标**: 修复 CI 构建失败问题，补全缺失文件
- **修复**:
  - 修复 intl 版本冲突 (flutter_localizations 要求 intl 0.18.1)
  - 移除缺失的字体和资源引用
  - 补全 Windows runner 文件（由 CI 自动生成）
  - 清理未使用的依赖项
  - 修复 Android Gradle 构建（新版 plugin 声明方式）
  - 修复 Dart 编译错误
  - 修复 Android 资源链接失败
  - 更新版本号到 0.1.1

### v0.1.0
- **状态**: 已发布
- **目标**: 使用 Flutter 重新实现 Bilibili 视频下载器
- **功能**:
  - Bilibili 视频搜索
  - 视频详情查看 (分P、画质选择)
  - Bilibili 扫码登录
  - 视频下载 (优先最高画质)
  - 下载任务管理 (进度、暂停、取消、重试)
  - 下载历史记录
  - 本地存储 (设置、历史)
  - 日志系统
  - 精美 Material Design 界面
  - 自适应布局 (手机/折叠屏/平板)
  - 简体中文界面
