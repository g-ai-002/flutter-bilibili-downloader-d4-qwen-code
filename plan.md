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
- [x] 实现下载速度实时显示
- [x] 实现搜索类型切换（视频/UP主）

---

## 版本历史

### v0.4.23 (PATCH) — 当前开发版本
- **状态**: 开发中 🔧
- **目标**: 版本号升级
- **任务**:
  - [x] 版本号升至 0.4.23

### v0.4.22 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 下载卡片作者/时间移至分集名下方 + 版本历史完善
- **任务**:
  - [x] 下载卡片作者/时间移至分集名下方
  - [x] 完善 README/plan 版本历史
  - [x] 版本号升至 0.4.22

### v0.4.21 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 下载卡片重构 + 元数据标签完善
- **任务**:
  - [x] 下载卡片状态图标+文本移至视频标题上方
  - [x] 下载卡片标题下方新增 UP 主名称和发布时间
  - [x] 已完成任务元数据添加中文标签（时长/大小/分辨率/帧率）
  - [x] DownloadJob 模型扩展 uploader/pubdate 字段 + 全链路透传
  - [x] 版本号升至 0.4.21

### v0.4.20 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 搜索页 Tab 栏高度优化 + 内容区空白消除
- **任务**:
  - [x] Tab 栏高度缩小约 1/3（46→32px），字体 13→12
  - [x] 消除搜索历史/搜索结果与导航栏之间的空白区域
  - [x] 所有 ListView 显式设置 padding: EdgeInsets.zero
  - [x] 版本号升至 0.4.20

### v0.4.19 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 搜索页重构 — 彻底解决滚动抖动和卡顿
- **任务**:
  - [x] NestedScrollView 替换为 Column+Expanded 固定布局
  - [x] 搜索框和 TabBar 作为固定组件，不受内容滚动影响
  - [x] 移除 ClampingScrollPhysics、NeverScrollableScrollPhysics、_TabBarDelegate
  - [x] 添加 MediaQuery 顶部安全区适配
  - [x] 版本号升至 0.4.19

### v0.4.18 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 界面底色统一 + 搜索页固定导航栏禁用弹性滚动
- **任务**:
  - [x] 统一界面底色
  - [x] 搜索页固定导航栏禁用弹性滚动（ClampingScrollPhysics）
  - [x] 版本号升至 0.4.18

### v0.4.12 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 导航栏 UI 精细化 — 0.5px 分隔线、降低导航栏高度、搜索框去边框浅灰底色

### v0.4.10 (PATCH)
- **状态**: 开发中 🔧
- **目标**: 下载视频时长元数据显示 + 搜索类型切换改为 Tab 栏
- **任务**:
  - [x] 下载完成视频卡片增加视频时长显示（从 BiliVideoDetail.duration 获取，下载后 ffprobe 补充）
  - [x] 搜索类型切换（视频/UP主）从搜索框内移出，改为导航栏内 Tab 栏
  - [x] Tab 栏随滚动隐藏/显示（SliverAppBar floating: true, snap: true）
  - [x] 更新版本号到 0.4.10

### v0.4.9 (PATCH)
- **状态**: 已发布 ✅
- **目标**: CI 构建修复 + Gradle 配置优化

### v0.4.8 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 search_page 括号错误

### v0.4.7 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 灰底更浅、搜索类型下拉合并到搜索框

### v0.4.1 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 主题色修正为 B 站粉 (#FB7299)
- **任务**:
  - [x] 主题色从 B 站蓝改为 B 站粉，同步更新浅色/深色 colorScheme 相关色板

### v0.4.0 (MINOR)
- **状态**: 已发布 ✅
- **目标**: UI 国内审美改造 — 去阴影、灰底白卡、0.5px 极细线、标题居中、去水波纹
- **任务**:
  - [x] 创建 `lib/theme/china_app_theme.dart` — 浅色/深色国内审美全局主题
  - [x] `main.dart` 集成新主题 + 沉浸式状态栏
  - [x] 底部导航从 NavigationBar 切换为 BottomNavigationBar（纯净图标+文字变色）
  - [x] NavigationRail 去背景色 + 0.5px VerticalDivider
  - [x] Card/Divider/AppBar/按钮 全局去阴影 + 0.5px 分割线
  - [x] 去除全局水波纹效果（splashColor/highlightColor=transparent）
  - [x] 输入框 0.5px 细边框 + 小圆角
  - [x] 版本号升至 0.4.0

### v0.2.41 (PATCH)
- **状态**: 已发布 ✅
- **目标**: Windows/Android 双平台依赖分离管理 — Windows 使用原生 ffmpeg (Process.run)，Android 使用 ffmpeg_kit_extended_flutter
- **任务**:
  - [x] 创建 pubspec_android.yaml（含 ffmpeg_kit_extended_flutter）和 pubspec_windows.yaml（不含）
  - [x] 创建平台特定 ffmpeg 实现文件：ffmpeg_android.dart / ffmpeg_windows.dart / ffmpeg_platform.dart
  - [x] file_system_service.dart 移除 ffmpeg_kit_wrapper 导入，改为委托 ffmpeg_platform.dart
  - [x] resolveFfmpeg() 从 FileSystemService 移至 ffmpeg_windows.dart（避免循环依赖）
  - [x] main.dart 通过 initializeFfmpeg() 统一初始化，不再直接引用 FFmpegKitExtended
  - [x] CI 工作流：Android/Windows 构建前互换 pubspec 和 platform dart 文件

### v0.2.36 (PATCH)
- **状态**: 已发布 ✅
- **目标**: Windows 平台 DASH 合并切换到 ffmpeg_kit_extended_flutter，统一双平台合并方案
- **任务**:
  - [x] Windows 平台 mergeAv() 改用 ffmpeg_kit_extended_flutter（与 Android 统一），移除 Process.run 外部 ffmpeg 调用
  - [x] 移除 FileSystemService.resolveFfmpeg() / hasFFmpeg()
  - [x] 移除 CI Windows 构建中 ffmpeg.exe 捆绑步骤
  - [x] 更新 UI 提示文案（不再提示安装系统 ffmpeg）
- **注意**: v0.2.41 中 Windows 重新回到原生 ffmpeg 调用（Process.run），恢复 resolveFfmpeg() 和 CI ffmpeg 捆绑

### v0.2.34 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 CI Windows 构建失败 + Issue #13
- **任务**:
  - [x] 修复 CI Windows 构建失败 — 移除 ffmpeg_kit_extended_flutter 依赖，改用平台通道实现 Android 合并
  - [x] 修复 Issue #13 — Android 应用图标美化 + 桌面显示应用名称
  - [x] CI 构建通过
  - [x] 关闭 Issue #13

### v0.2.17 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #12（2 项反馈）
- **任务**:
  - [x] 修复 Windows 下载管理批量清理/删除按钮无作用
  - [x] 修复 Android Media3 Transformer 合并失败：`Unsupported sample MIME type video/mp4`
  - [x] CI 构建通过

### v0.2.16 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 CI 编译错误（v0.2.15 遗留）
- **任务**:
  - [x] 修复 bilibili_api.dart 缺少 StorageService import 导致编译失败
  - [x] 修复 download_service.dart num/int 类型不匹配导致编译失败
  - [x] CI 构建通过

### v0.2.15 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #10（5 项反馈）+ Issue #11（Media3 Transformer 无损合并）
- **任务**:
  - [x] Issue #10.1: 断点续传功能（app 重启后恢复下载）
  - [x] Issue #10.2: Android 合并超时从 120s 增大到 10 小时
  - [x] Issue #10.3: 下载管理批量清理不同状态任务
  - [x] Issue #10.4: 下载任务显示下载/合并/总用时、已执行和剩余时间
  - [x] Issue #10.5: Cookie 登录信息持久化改进
  - [x] Issue #11: Media3 Transformer 使用 setVideoMimeType 实现无损合并

### v0.2.14 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #9 — Media3 Transformer 线程错误导致合并失败
- **任务**:
  - [x] 修复 Transformer 须在主线程上创建和调用的问题
  - [x] 移除 Thread 包装和 CountDownLatch，改用回调 + Handler 方案

### v0.2.13 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #9 — MediaMuxer 合并仍报 IllegalArgumentException，改用 Jetpack Media3 Transformer
- **任务**:
  - [x] 引入 media3-transformer 依赖
  - [x] 使用 Composition + Transformer 方案替换原生 MediaMuxer
  - [x] 实现异步合并，支持详细错误信息

### v0.2.12 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #9 — 移除已停更的 ffmpeg-kit，完善原生 MediaMuxer 合并
- **任务**:
  - [x] 移除 ffmpeg-kit-min 依赖（CI 构建失败根因）
  - [x] 移除 MainActivity.kt 中所有 ffmpeg-kit 代码
  - [x] 完善原生 MediaMuxer 合并的错误处理

### v0.2.11 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #9 — Android MediaMuxer 合并失败
- **修复**:
  - [x] MediaMuxer writeTrack 添加 buffer.clear()，修复 buffer 位置累积导致 MERGE_FAILED
  - [x] Android 引入 ffmpeg-kit-min 6.0-2 作为回退方案，MediaMuxer 失败时自动切换
  - [x] 改进合并失败时的错误信息，同时展示 MediaMuxer 和 ffmpeg 的错误详情

### v0.2.10 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #8
- **修复**:
  - [x] Android DASH 视频/音频合并：使用 Android MediaMuxer 原生 API 实现合并，无需外部 ffmpeg
  - [x] 下载中/排队中任务支持删除：下载管理页为所有状态添加删除按钮，delete 时自动 cancel 下载

### v0.2.9 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 CI 构建失败（v0.2.8 遗留编译错误）
- **修复**:
  - [x] home_page.dart：SnackBar 移除 const（引用实例方法 _navigateToLogin）
  - [x] video_detail_page.dart：nullable 类型 chosen 添加 null-assert

### v0.2.8 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #7 反馈的 9 大问题
- **修复**:
  - [x] Windows DASH 下载完成进度卡在 98%：处理 total=-1 未知大小；进度 clamp 到 99 并在合并阶段显示 99%
  - [x] 下载速度与实际网速不符：每个 part 独立跟踪速度计算，基于时间窗口 + Part 增量
  - [x] 下载失败/取消任务支持删除
  - [x] Windows 字体设为 Microsoft YaHei UI
  - [x] 下载管理列表支持搜索
  - [x] Cookie 持久化：main() 中预加载 SettingsProvider
  - [x] 启动时检测登录信息有效性，失效则提示重新登录
  - [x] 视频详情页第二次打开卡死：clearDetail() + bvid 校验 + 错误重试按钮
  - [x] 视频列表和详情页显示发布时间

### v0.2.7 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #6 评论补充反馈（画质选择 / Windows ffmpeg 内置 / LateInitializationError 与 412 风控）
- **修复**:
  - [x] 视频详情页画质选择新增显式 Dropdown + ChoiceChip + 当前画质提示，算法改用 quality int 比较
  - [x] GitHub Actions Windows 构建自动内置 ffmpeg.exe / ffprobe.exe（基于 GyanD ffmpeg-7.0.2-essentials），开箱即用
  - [x] `FileSystemService.resolveFfmpeg` 优先使用应用同目录 ffmpeg，回退到 PATH
  - [x] StorageService 改用 `_initFuture` 缓存避免并发竞态导致的 `LateInitializationError(_prefs)`
  - [x] main() 中预先 await StorageService 初始化，杜绝后续 Provider 拿到未就绪实例
  - [x] NotificationService 新增平台守卫（仅 Android/iOS/macOS/Linux），并补全 Linux/macOS 初始化设置
  - [x] BilibiliApi 启动时主动访问 www.bilibili.com 获取 `buvid3` cookie 规避 412 风控
  - [x] 412 / -101(未登录) / -10403(大会员专享) 等错误转换为面向用户的中文提示
  - [x] `getPlayUrl` 失败抛出 `BilibiliApiException`，下载层透传到 UI；业务错误不再无意义重试

### v0.2.6 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #6（综合反馈 9 项）
- **修复**:
  - [x] Windows DASH 下载自动调用系统 ffmpeg 合并视频/音频
  - [x] Android 下载到外部存储 Movies/Bilibili，文件管理器可见
  - [x] UP 主点击进入独立视频列表页，并可继续进入详情
  - [x] 已完成任务新增"打开所在目录"按钮（桌面端打开文件管理器）
  - [x] 首选画质默认 4K，画质优先级以 4K 为最高优先
  - [x] 设置页新增日志目录展示，支持复制路径、打开目录
  - [x] 显示已登录账号头像 + 用户名（调用 nav 接口）
  - [x] 宽屏（>=900px）切换为 NavigationRail 主从布局

### v0.2.5 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #5 — Android 上下载的视频文件不存在
- **修复**:
  - [x] 优先使用单文件格式下载（fnval=16）
  - [x] DASH 回退时 filePath 指向实际存在的视频文件

### v0.2.4 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #4 — 显示已下载视频的本地存储地址
- **修复**:
  - [x] 下载页面已完成任务卡片显示文件存储路径，支持点击复制
  - [x] 设置页面增加下载目录信息展示，支持复制路径
  - [x] 优化 Android 存储权限（minSdk 34 使用应用专属存储无需额外权限）

### v0.2.3 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 重构优化存量代码，提升代码质量和健壮性
- **重构**:
  - [x] 修复 StorageService 单例模式，避免重复初始化
  - [x] 修复 SearchPage 搜索历史竞态条件
  - [x] 修复 DownloadService DASH CancelToken 管理
  - [x] 合并 DownloadService._downloadFile 和 _downloadPart 消除重复代码
  - [x] 拆分 DownloadService._startDownload 长方法
  - [x] 优化 BilibiliApi WBI 密钥获取重试机制
  - [x] 优化 VideoDetailPage 画质选择时机

### v0.2.2 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #3 — DASH 下载进度回退、速度计算异常
- **修复**:
  - [x] DASH 下载时视频轨和音频轨分别下载导致进度条回退到 0%
  - [x] 音频轨下载时速度计算重置导致速度显示异常
  - [x] 合并视频轨和音频轨的进度计算，使用总进度而非单文件进度

### v0.2.1 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #2 — DownloadJob 缺少 cid 导致下载进度始终为 0

### v0.2.0 (MINOR)
- **状态**: 已发布 ✅
- **目标**: 下载历史持久化 + 画质选择交互 + 下载速度显示 + 搜索类型切换 + 下载完成通知
- **任务**:
  - [x] 下载历史持久化 — 将下载记录保存到本地存储，重启后可查看历史下载记录
  - [x] 画质选择交互优化 — 用户可在视频详情页点击选择不同画质，而非仅展示
  - [x] 下载速度实时显示 — 在下载卡片中实时更新下载速度
  - [x] 搜索类型切换 — 支持在视频搜索和 UP 主搜索之间切换
  - [x] 下载完成通知 — 下载完成后显示通知提示

### v0.1.3 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 Issue #1 — WBI 签名缺失导致搜索失败
- **修复**:
  - [x] 修复 Bilibili 搜索 API 缺少 WBI 签名
  - [x] 修复视频画质获取接口缺少 WBI 签名
  - [x] 修复 CI Windows 构建流程，确保生成 Windows Release

### v0.1.2 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 重构优化，提升代码质量
- **修复**:
  - [x] 统一 API 实例管理，避免创建重复实例
  - [x] 修复画质选择优先级逻辑 Bug
  - [x] 改进 DownloadService 空对象模式，使用 indexWhere 替代 firstWhere
  - [x] 添加 CancelToken 支持，实现下载任务真正取消
  - [x] 移除冗余代码（SearchPage 多余 setState）
  - [x] 改进 LogService 线程安全性和异常处理
  - [x] 修复搜索历史重复项问题
  - [x] 版本号统一管理（settings_page 引用 AppConstants.version）
  - [x] 增加测试覆盖（模型、工具类）

### v0.1.1 (PATCH)
- **状态**: 已发布 ✅
- **目标**: 修复 CI 构建 + Android 编译错误
- **修复**:
  - [x] 修复 intl 版本冲突导致 CI 构建失败
  - [x] 修复 assets 目录和字体文件缺失
  - [x] 补全 Windows runner 文件
  - [x] 清理未使用的依赖
  - [x] 修复 Android Gradle 构建（改用新版 plugin 声明方式）
  - [x] 修复 Dart 编译错误
  - [x] 修复 Android 资源链接失败
  - [x] CI 构建通过 ✅

### v0.1.0 (MINOR)
- **状态**: 已发布 ✅
- **目标**: 项目初始化 — Bilibili 视频下载器首版
- **任务**:
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
