import 'dart:io' show Platform;
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/search_provider.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'pages/home_page.dart';
import 'services/log_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 提前完成 StorageService 初始化，避免后续多个 Provider 并发
  // 触发 SharedPreferences 异步加载竞态，导致 LateInitializationError。
  await StorageService.instance;
  await LogService.init();
  await NotificationService.instance.init();

  // 初始化 ffmpeg_kit_extended_flutter
  await FFmpegKitExtended.initialize();

  // 预加载设置，确保 Cookies 等配置在应用启动时已就绪
  final settings = SettingsProvider();
  await settings.load();

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
            title: 'Bilibili 下载器',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF00A1D6),
              useMaterial3: true,
              brightness: Brightness.light,
              fontFamily: defaultFontFamily,
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: const Color(0xFF00A1D6),
              useMaterial3: true,
              brightness: Brightness.dark,
              fontFamily: defaultFontFamily,
            ),
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
