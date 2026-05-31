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
  runApp(const BilibiliDownloaderApp());
}

class BilibiliDownloaderApp extends StatelessWidget {
  const BilibiliDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
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
            ),
            darkTheme: ThemeData(
              colorSchemeSeed: const Color(0xFF00A1D6),
              useMaterial3: true,
              brightness: Brightness.dark,
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
