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

  // 提前完成 StorageService 初始化，避免后续多个 Provider 并发
  // 触发 SharedPreferences 异步加载竞态，导致 LateInitializationError。
  await StorageService.instance;
  await LogService.init();
  await NotificationService.instance.init();

  // 初始化 ffmpeg（Android: ffmpeg_kit_extended_flutter; Windows: 无操作）
  await initializeFfmpeg();

  // 预加载设置，确保 Cookies 等配置在应用启动时已就绪
  final settings = SettingsProvider();
  await settings.load();

  // 沉浸式状态栏：透明背景 + 深色图标
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(BilibiliDownloaderApp(preloadedSettings: settings));
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
