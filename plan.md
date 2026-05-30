# Bilibili 视频下载器 - Flutter 版本

## 项目规划

### 长期目标
- 构建一个功能完善的 Bilibili 视频下载 Flutter 应用
- 支持 Android 和 Windows 双平台
- 提供精美的 Material Design 界面
- 支持扫码登录、视频搜索、高清下载

### 中期目标
- [x] 实现 Bilibili API 完整封装
- [x] 实现多任务下载管理
- [x] 实现下载进度实时显示
- [x] 实现本地下载历史管理
- [ ] 实现下载速度实时显示
- [ ] 实现搜索类型切换（视频/UP主）

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

### v0.1.2 (PATCH)
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

### v0.1.3 (PATCH)
- [x] 修复 Bilibili 搜索 API 缺少 WBI 签名导致搜索失败
- [x] 修复视频画质获取接口缺少 WBI 签名
- [x] 修复 CI Windows 构建流程，确保生成 Windows Release
- [x] 更新版本号到 0.1.3

### v0.2.0 (MINOR)
- [x] **下载历史持久化** - 将下载记录保存到本地存储，重启后可查看历史下载记录
- [x] **画质选择交互优化** - 用户可在视频详情页点击选择不同画质，而非仅展示
- [x] **下载速度实时显示** - 在下载卡片中实时更新下载速度
- [x] **搜索类型切换** - 支持在视频搜索和UP主搜索之间切换
- [x] **下载完成通知** - 下载完成后显示通知提示
- [x] **更新版本号到 0.2.0**

### v0.2.1 (PATCH)
- [x] **修复 Issue #2** - DownloadJob 缺少 cid 字段导致下载进度始终为 0
- [x] **更新版本号到 0.2.1**

### v0.2.2
- [x] **修复 Issue #3** - DASH 下载时视频轨和音频轨分别下载导致进度条回退到 0%
- [x] **修复下载速度计算** - 音频轨下载时速度计算重置导致速度显示异常
- [x] **优化 DASH 下载流程** - 合并视频轨和音频轨的进度计算，使用总进度而非单文件进度
- [x] **更新版本号到 0.2.2**

### v0.2.3 (PATCH)
- [x] **修复 StorageService 单例模式** - 避免每次调用 instance 都重新 await SharedPreferences.getInstance()
- [x] **修复 SearchPage 搜索历史竞态条件** - 简化搜索历史保存逻辑，避免重复操作
- [x] **修复 DownloadService DASH CancelToken 管理** - 确保 DASH 下载中视频轨和音频轨都能被正确取消
- [x] **合并 DownloadService._downloadFile 和 _downloadPart** - 消除重复代码
- [x] **优化 DownloadService._startDownload 拆分长方法** - 将过长的 _startDownload 拆分为职责明确的小方法
- [x] **优化 BilibiliApi WBI 密钥获取重试** - 添加 WBI 密钥获取失败的重试机制
- [x] **优化 VideoDetailPage 画质选择时机** - 在详情加载完成后自动选择最佳画质
- [x] **更新版本号到 0.2.3**

### v0.2.4 (当前版本 - PATCH)
- [x] **修复 Issue #4** - 显示已下载视频的本地存储地址
- [x] **下载页面显示文件路径** - 已完成下载的任务卡片显示文件存储路径，支持复制
- [x] **设置页面显示下载目录** - 设置页面增加下载目录信息展示，支持复制路径
- [x] **优化 Android 存储权限** - 移除不必要的存储权限声明（minSdk 34 使用应用专属存储无需额外权限）
- [x] **更新版本号到 0.2.4**

---

## 版本历史

### v0.2.4 (当前版本)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #4 - 显示已下载视频的本地存储地址
- **修复**:
  - 下载页面已完成任务卡片显示文件存储路径，支持点击复制
  - 设置页面增加下载目录信息展示，支持复制路径
  - 优化 Android 存储权限（minSdk 34 使用应用专属存储无需额外权限）

### v0.2.3
- **状态**: 已发布 ✅
- **目标**: 重构优化存量代码，提升代码质量和健壮性
- **重构**:
  - 修复 StorageService 单例模式，避免重复初始化
  - 修复 SearchPage 搜索历史竞态条件
  - 修复 DownloadService DASH CancelToken 管理
  - 合并 DownloadService._downloadFile 和 _downloadPart 消除重复代码
  - 拆分 DownloadService._startDownload 长方法
  - 优化 BilibiliApi WBI 密钥获取重试机制
  - 优化 VideoDetailPage 画质选择时机

### v0.2.2
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #3 - 下载进度回退和速度计算问题
- **修复**:
  - DASH 下载时视频轨和音频轨分别下载导致进度条回退到 0%
  - 音频轨下载时速度计算重置导致速度显示异常
  - 优化 DASH 下载流程，合并视频轨和音频轨的进度计算

### v0.2.1
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #2 - 下载进度始终为 0 的问题
- **修复**:
  - DownloadJob 模型添加 cid 字段，确保下载时能正确获取播放地址
  - 修复 download_service 中 cid 参数传递错误（误将 formatId 当作 cid 传入）

### v0.2.0
- **状态**: 已发布 ✅
- **目标**: 新增下载历史持久化、画质选择交互优化、下载速度实时显示、搜索类型切换、下载完成通知
- **新增**:
  - 下载历史持久化，重启后可查看历史下载记录
  - 画质选择交互优化，用户可在视频详情页点击选择不同画质
  - 下载速度实时显示，在下载卡片中实时更新下载速度
  - 搜索类型切换，支持在视频搜索和UP主搜索之间切换
  - 下载完成通知，下载完成后显示通知提示

### v0.1.3
- **状态**: 已发布 ✅
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
