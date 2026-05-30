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

### v0.1.1 (当前版本 - PATCH)
- [x] 修复 intl 版本冲突导致 CI 构建失败
- [x] 修复 assets 目录和字体文件缺失
- [x] 补全 Windows runner 文件（由 CI 自动生成）
- [x] 清理未使用的依赖
- [x] 修复 Android Gradle 构建（改用新版 plugin 声明方式）
- [x] 修复 Dart 编译错误 (retryCount, surfaceContainerHighest, cookies, 图标)
- [x] 修复 Android 资源链接失败（移除缺失图标引用）
- [x] 更新版本号到 0.1.1
- [x] CI 构建通过 ✅

---

## 版本历史

### v0.1.1 (当前版本)
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
