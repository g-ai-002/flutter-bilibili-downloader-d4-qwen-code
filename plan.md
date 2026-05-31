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

### v0.2.4 (PATCH)
- [x] **修复 Issue #4** - 显示已下载视频的本地存储地址
- [x] **下载页面显示文件路径** - 已完成下载的任务卡片显示文件存储路径，支持复制
- [x] **设置页面显示下载目录** - 设置页面增加下载目录信息展示，支持复制路径
- [x] **优化 Android 存储权限** - 移除不必要的存储权限声明（minSdk 34 使用应用专属存储无需额外权限）
- [x] **更新版本号到 0.2.4**

### v0.2.5
- [x] **修复 Issue #5** - Android 上下载的视频文件不存在
- [x] **优先使用单文件格式下载** - API 请求优先使用非 DASH 格式（fnval=16），确保下载文件为含音视频的单文件
- [x] **DASH 回退时修正 filePath** - DASH 格式下载时 filePath 指向实际存在的视频文件而非不存在的合并文件
- [x] **更新版本号到 0.2.5**

### v0.2.6 (PATCH)
- [x] **修复 Issue #6.1** - Windows 下 DASH 视频/音频自动合并（系统 ffmpeg 可用时调用，失败时保留双文件并明确提示）
- [x] **修复 Issue #6.2** - Android 下载文件保存到外部存储 Movies/Bilibili 目录，便于通过系统文件管理器和图库查看
- [x] **修复 Issue #6.3** - UP 主搜索结果点击后跳转到独立的 UP 主视频列表页面，并支持继续点击进入视频详情
- [x] **修复 Issue #6.4** - 搜索历史与下载记录持久化（已有实现，补充下载历史展示与 UP 主搜索历史复用）
- [x] **修复 Issue #6.5** - 已完成下载任务增加"打开所在目录"按钮（Windows: explorer / Android: 文件路径 + 复制）
- [x] **修复 Issue #6.6** - 首选画质默认调整为 4K，画质优先级以 4K 为首选
- [x] **修复 Issue #6.7** - 设置页显示日志所在目录路径，支持复制 / 打开
- [x] **修复 Issue #6.8** - 显示已登录账号名称（调用 nav 接口获取用户名 + 头像）
- [x] **修复 Issue #6.9** - 宽屏（>=900px）使用 NavigationRail + 主从布局（左侧导航 + 右侧内容），手机端保持底部导航
- [x] **更新版本号到 0.2.6**

### v0.2.7 (当前版本 - PATCH)
修复 Issue #6 补充评论反馈的 3 大问题：
- [x] **修复 Issue #6 补充 1** - 视频详情页画质选择交互优化：增加显式 Dropdown，画质 Chip 改为 ChoiceChip 并显示"当前画质"提示；选择算法改为基于 quality int 的稳定优先级（避免 `contains` 误匹配）
- [x] **修复 Issue #6 补充 2** - Windows 构建在 GitHub Actions 中自动下载并打包 ffmpeg.exe/ffprobe.exe 到 release zip 同目录，开箱即用无需用户安装；`FileSystemService.resolveFfmpeg` 同步支持"先查应用同目录，再回退到 PATH"
- [x] **修复 Issue #6 补充 3.1** - 修复 `LateInitializationError: Field '_prefs' has not been initialized`：StorageService 改用 `_initFuture` 缓存初始化 Future，避免并发调用 instance 出现的竞态；main() 启动时预初始化 StorageService
- [x] **修复 Issue #6 补充 3.2** - 修复 `LateInitializationError: Field '_instance' has not been initialized` 于 NotificationService：补充 Linux/macOS InitializationSettings；增加平台支持守卫（仅 Android/iOS/macOS/Linux 才调用插件）；初始化与展示全链路 try/catch 防御
- [x] **修复 Issue #6 补充 3.3** - 修复搜索 412 风控：BilibiliApi 启动时主动访问 www.bilibili.com 获取 `buvid3` cookie 并附加到所有后续请求；对 412 状态码与业务错误码（-101 未登录、-10403 大会员专享）给出明确中文提示
- [x] **修复 Issue #6 补充 3.4** - 修复"无法获取播放地址"含糊提示：getPlayUrl 失败时抛出可读的 `BilibiliApiException`，下载层透传到 UI；业务错误不重试，避免无意义重复刷接口
- [x] **更新版本号到 0.2.7**

---

## 版本历史

### v0.2.7 (当前版本)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #6 评论补充反馈（画质选择 / Windows ffmpeg 内置 / 多个 LateInitializationError 与 412 风控）
- **修复**:
  - 视频详情页画质选择新增显式 Dropdown + ChoiceChip + 当前画质提示，算法改用 quality int 比较
  - GitHub Actions Windows 构建自动内置 ffmpeg.exe / ffprobe.exe（基于 GyanD ffmpeg-7.0.2-essentials），开箱即用
  - `FileSystemService.resolveFfmpeg` 优先使用应用同目录 ffmpeg，回退到 PATH
  - StorageService 改用 `_initFuture` 缓存避免并发竞态导致的 `LateInitializationError(_prefs)`
  - main() 中预先 await StorageService 初始化，杜绝后续 Provider 拿到未就绪实例
  - NotificationService 新增平台守卫（仅 Android/iOS/macOS/Linux），并补全 Linux/macOS 初始化设置，避免 Windows 上插件抛 late 异常
  - BilibiliApi 启动时主动访问 www.bilibili.com 获取 `buvid3` cookie 规避 412 风控
  - 412 / -101(未登录) / -10403(大会员专享) 等错误转换为面向用户的中文提示
  - `getPlayUrl` 失败抛出 `BilibiliApiException`，下载层透传到 UI；业务错误不再无意义重试

### v0.2.6
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #6（综合反馈 9 项）
- **修复**:
  - Windows DASH 下载自动调用系统 ffmpeg 合并视频/音频
  - Android 下载到外部存储 Movies/Bilibili，文件管理器可见
  - UP 主点击进入独立视频列表页，并可继续进入详情
  - 已完成任务新增"打开所在目录"按钮（桌面端打开文件管理器）
  - 首选画质默认 4K，画质优先级以 4K 为最高优先
  - 设置页新增日志目录展示，支持复制路径、打开目录
  - 显示已登录账号头像 + 用户名（调用 nav 接口）
  - 宽屏（>=900px）切换为 NavigationRail 主从布局

### v0.2.5
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #5 - Android 上下载的视频文件不存在
- **修复**:
  - 优先使用单文件格式下载（fnval=16）
  - DASH 回退时 filePath 指向实际存在的视频文件

### v0.2.4
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

### v0.1.x - v0.2.2（历史版本合并）
- **状态**: 已发布 ✅
- **范围**: 项目初始化与早期迭代
- **要点**:
  - v0.1.0：使用 Flutter 重新实现 Bilibili 视频下载器，含搜索、扫码登录、下载管理、本地存储、日志、Material 3 自适应界面
  - v0.1.1：修复 CI 构建（intl 冲突、Android Gradle 新插件声明、Dart 编译错误、Android 资源链接失败）
  - v0.1.2：重构优化（统一 API 实例、画质选择 Bug、CancelToken、LogService 线程安全、增加测试覆盖）
  - v0.1.3：修复 Issue #1（WBI 签名、Windows Release 构建）
  - v0.2.0：下载历史持久化、画质选择交互、下载速度实时显示、搜索类型切换、下载完成通知
  - v0.2.1：修复 Issue #2（DownloadJob 缺少 cid 导致进度始终为 0）
  - v0.2.2：修复 Issue #3（DASH 下载进度回退、速度计算异常，统一进度合并）
