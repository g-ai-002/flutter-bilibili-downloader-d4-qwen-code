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
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    SearchPage(),
    DownloadPage(),
    SettingsPage(),
  ];

  static const _destinations = <_NavDestination>[
    _NavDestination(
      icon: Icons.search,
      selectedIcon: Icons.search_rounded,
      label: '搜索',
    ),
    _NavDestination(
      icon: Icons.download_outlined,
      selectedIcon: Icons.download_rounded,
      label: '下载',
    ),
    _NavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: '设置',
    ),
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

    // 创建统一的 API 实例（settings 已在 main() 中预加载，cookies 已就绪）
    final api = BilibiliApi(cookies: settings.bilibiliCookies);

    search.initApi(api);
    final downloadService = DownloadService(api);
    download.initService(downloadService);

    // 已登录则在启动时拉取一次账号信息，并验证 Cookies 有效性
    if (settings.bilibiliEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        settings.refreshUserInfo(api);
        _verifyCookies(settings, api);
      });
    }
  }

  Future<void> _verifyCookies(SettingsProvider settings, BilibiliApi api) async {
    try {
      final valid = await api.verifyCookies();
      if (!valid && mounted) {
        // Cookies 已失效，清除登录状态并提示用户
        await settings.setBilibiliCookies(null);
        context.read<SearchProvider>().updateCookies(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('登录信息已过期，请重新扫码登录'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '登录',
              onPressed: _navigateToLogin,
            ),
          ),
        );
      }
    } catch (_) {
      // 验证失败静默处理，不影响正常使用
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽屏（>=900）使用 NavigationRail 主从布局；窄屏使用底部导航
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return _buildWideLayout(context);
        }
        return _buildNarrowLayout(context);
      },
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
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
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
