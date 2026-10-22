import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

import 'providers/search_provider.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'pages/home_page.dart';
import 'services/ffmpeg_platform.dart';
import 'services/file_system_service.dart';
import 'services/log_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/china_app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows 平台：窗口启动时居中显示
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'B站视频下载',
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 启动阶段各步骤互相独立：任一步失败或超时都只记录日志并降级继续，
  // 绝不阻断 runApp()。否则某个插件不可用时会一直停在启动画面，
  // 用户只能看到一个 logo，既进不去主界面也拿不到失败原因。
  //
  // StorageService 提前初始化，避免后续多个 Provider 并发触发
  // SharedPreferences 异步加载竞态，导致 LateInitializationError。
  await _startupStep('本地存储初始化', () async {
    await StorageService.instance;
  });
  await _startupStep('日志服务初始化',
      () => LogService.init(logRoot: FileSystemService.instance.getLogRoot));
  await _startupStep('通知服务初始化', NotificationService.instance.init);

  // 初始化 ffmpeg（Android 与 Windows 均为 ffmpeg_kit_extended_flutter）
  await _startupStep('ffmpeg 初始化', initializeFfmpeg);

  // 预加载设置，确保 Cookies 等配置在应用启动时已就绪
  final settings = SettingsProvider();
  await _startupStep('设置加载', settings.load);

  LogService.info('启动流程执行完毕，进入主界面');

  // 沉浸式状态栏：透明背景 + 深色图标
  SystemChrome.setSystemUIOverlayStyle(const SystemUIOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(BilibiliDownloaderApp(preloadedSettings: settings));
}

/// 单个启动步骤的超时上限
const _startupStepTimeout = Duration(seconds: 10);

/// 执行一个启动步骤，失败或超时只记录日志并继续。
///
/// 启动阶段的插件调用（SharedPreferences / path_provider / 通知 / ffmpeg）
/// 任一不可用都不应该让应用卡在启动画面，这里统一做兜底，
/// 失败原因会写入日志（设置页可查看）。
Future<void> _startupStep(String name, Future<void> Function() action) async {
  final stopwatch = Stopwatch()..start();
  try {
    await action().timeout(_startupStepTimeout);
    LogService.info('启动步骤完成: $name (${stopwatch.elapsedMilliseconds}ms)');
  } catch (e, stack) {
    // 超时也走这里，异常文本形如 TimeoutException after 0:00:10.000000
    final failure = '[启动] 步骤失败（已降级继续）: $name';
    // 日志服务未就绪时进入早期缓冲，初始化后自动补写；debugPrint 便于在 logcat 中即时查看
    LogService.error(failure, e, stack);
    debugPrint('$failure | $e');
  }
}

class BilibiliDownloaderApp extends StatelessWidget {
  final SettingsProvider preloadedSettings;

  const BilibiliDownloaderApp({super.key, required this.preloadedSettings});

  @override
  Widget build(BuildContext context) {
    // Windows 平台优先使用 Microsoft YaHei UI 字体
    final defaultFontFamily = Platform.isWindows ? 'Microsoft YaHei UI' : null;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: preloadedSettings),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'B站视频下载',
            debugShowCheckedModeBanner: false,
            theme: chinaLightTheme(fontFamily: defaultFontFamily),
            darkTheme: chinaDarkTheme(fontFamily: defaultFontFamily),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
