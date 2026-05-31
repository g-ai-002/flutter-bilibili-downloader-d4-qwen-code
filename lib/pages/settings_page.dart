import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/search_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _logContent = '';
  String _downloadDir = '';
  String _logDir = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadDirs();
    // 进入设置页时刷新登录账号信息
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUser());
  }

  Future<void> _refreshUser() async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final api = context.read<SearchProvider>().api;
    if (api != null && settings.bilibiliEnabled) {
      await settings.refreshUserInfo(api);
    }
  }

  Future<void> _loadLogs() async {
    final logs = LogService.getRecentLogs(50);
    if (mounted) {
      setState(() => _logContent = logs.join('\n'));
    }
  }

  Future<void> _loadDirs() async {
    try {
      final downloadRoot = await FileSystemService.instance.getDownloadRoot();
      final logRoot = await FileSystemService.instance.getLogRoot();
      if (mounted) {
        setState(() {
          _downloadDir = downloadRoot.path;
          _logDir = logRoot.path;
        });
      }
    } catch (_) {}
  }

  bool get _canOpenDir =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 外观
          const _SectionHeader(title: '外观'),
          SwitchListTile(
            title: const Text('深色模式'),
            subtitle: const Text('切换深色/浅色主题'),
            secondary: Icon(
              settings.darkMode ? Icons.dark_mode : Icons.light_mode,
              color: theme.colorScheme.primary,
            ),
            value: settings.darkMode,
            onChanged: (value) => settings.setDarkMode(value),
          ),

          const Divider(),

          // Bilibili 账号
          const _SectionHeader(title: 'Bilibili 账号'),
          _buildAccountTile(context, settings, theme),

          const Divider(),

          // 下载设置
          const _SectionHeader(title: '下载设置'),
          ListTile(
            leading: Icon(Icons.high_quality, color: theme.colorScheme.primary),
            title: const Text('首选画质'),
            subtitle: Text(settings.preferredQuality),
            trailing: DropdownButton<String>(
              value: settings.preferredQuality,
              items: const [
                DropdownMenuItem(value: '4K', child: Text('4K')),
                DropdownMenuItem(value: '1080P+', child: Text('1080P+')),
                DropdownMenuItem(value: '1080P', child: Text('1080P')),
                DropdownMenuItem(value: '720P', child: Text('720P')),
                DropdownMenuItem(value: '480P', child: Text('480P')),
              ],
              onChanged: (value) {
                if (value != null) settings.setPreferredQuality(value);
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.download, color: theme.colorScheme.primary),
            title: const Text('最大下载任务数'),
            subtitle: Text('${settings.maxJobs} 个'),
            trailing: SizedBox(
              width: 120,
              child: Slider(
                value: settings.maxJobs.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                label: '${settings.maxJobs}',
                onChanged: (value) => settings.setMaxJobs(value.round()),
              ),
            ),
          ),
          // 下载目录
          if (_downloadDir.isNotEmpty)
            _buildDirTile(
              theme,
              icon: Icons.folder,
              title: '下载目录',
              path: _downloadDir,
              hint: Platform.isAndroid
                  ? '可通过文件管理器/图库访问'
                  : '点击右侧按钮打开目录',
            ),

          const Divider(),

          // 关于
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            title: const Text('版本'),
            subtitle: Text(AppConstants.version),
          ),
          // 日志目录
          if (_logDir.isNotEmpty)
            _buildDirTile(
              theme,
              icon: Icons.folder_special,
              title: '日志目录',
              path: _logDir,
              hint: '出现问题时可提供此目录下日志文件',
            ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
            title: const Text('查看日志'),
            subtitle: const Text('查看应用运行日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLogDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
      BuildContext context, SettingsProvider settings, ThemeData theme) {
    if (!settings.bilibiliEnabled) {
      return ListTile(
        leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
        title: const Text('未登录'),
        subtitle: const Text('登录后可下载更高画质视频'),
        trailing: FilledButton.tonal(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ),
          child: const Text('扫码登录'),
        ),
      );
    }

    final user = settings.userInfo;
    return ListTile(
      leading: user != null && user.face.isNotEmpty
          ? CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(user.face),
              backgroundColor: theme.colorScheme.surfaceVariant,
            )
          : Icon(Icons.account_circle, color: theme.colorScheme.primary, size: 40),
      title: Text(
        user != null && user.uname.isNotEmpty ? user.uname : '已登录',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        user != null && user.mid > 0
            ? 'UID: ${user.mid}${user.level > 0 ? ' · Lv${user.level}' : ''}'
            : '已启用 Cookies 登录',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新账号信息',
            onPressed: _refreshUser,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: () async {
              await settings.setBilibiliCookies(null);
              if (!mounted) return;
              context.read<SearchProvider>().updateCookies(null);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出登录')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDirTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String path,
    required String hint,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.copy, color: theme.colorScheme.primary),
            tooltip: '复制路径',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: path));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title已复制到剪贴板'), duration: const Duration(seconds: 2)),
              );
            },
          ),
          if (_canOpenDir)
            IconButton(
              icon: Icon(Icons.open_in_new, color: theme.colorScheme.primary),
              tooltip: '打开目录',
              onPressed: () async {
                final ok = await FileSystemService.instance.openDirectory(path);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('当前平台不支持打开目录')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  void _showLogDialog(BuildContext context) {
    _loadLogs();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('应用日志'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLogs,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _logContent.isEmpty ? '暂无日志' : _logContent,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
