import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../services/bilibili_api.dart';
import '../services/download_service.dart';
import 'search_page.dart';
import 'download_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = const [
    SearchPage(),
    DownloadPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  void _initServices() {
    final settings = context.read<SettingsProvider>();
    final search = context.read<SearchProvider>();
    final download = context.read<DownloadProvider>();

    // 创建统一的 API 实例
    final api = BilibiliApi(cookies: settings.bilibiliCookies);

    // 初始化搜索和下载服务共享同一 API 实例
    search.initApi(api);
    final downloadService = DownloadService(api);
    // 异步初始化下载服务（加载持久化数据）
    download.initService(downloadService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search_rounded),
            label: '搜索',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_rounded),
            label: '下载',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
