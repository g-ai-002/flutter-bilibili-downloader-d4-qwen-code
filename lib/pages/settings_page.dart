import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/settings_provider.dart';
import '../providers/search_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadDownloadDir();
  }

  Future<void> _loadLogs() async {
    final logs = LogService.getRecentLogs(50);
    if (mounted) {
      setState(() => _logContent = logs.join('\n'));
    }
  }

  Future<void> _loadDownloadDir() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (mounted) {
        setState(() => _downloadDir = '${dir.path}/downloads');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 外观
          _SectionHeader(title: '外观'),
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
          _SectionHeader(title: 'Bilibili 账号'),
          ListTile(
            leading: Icon(Icons.person, color: theme.colorScheme.primary),
            title: Text(settings.bilibiliEnabled ? '已登录' : '未登录'),
            subtitle: Text(
              settings.bilibiliEnabled ? '已启用 Cookies 登录' : '登录后可下载更高画质视频',
            ),
            trailing: settings.bilibiliEnabled
                ? IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: '退出登录',
                    onPressed: () async {
                      await settings.setBilibiliCookies(null);
                      context.read<SearchProvider>().updateCookies(null);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已退出登录')),
                        );
                      }
                    },
                  )
                : FilledButton.tonal(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                    child: const Text('扫码登录'),
                  ),
          ),

          const Divider(),

          // 下载设置
          _SectionHeader(title: '下载设置'),
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
            ListTile(
              leading: Icon(Icons.folder, color: theme.colorScheme.primary),
              title: const Text('下载目录'),
              subtitle: Text(
                _downloadDir,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: Icon(Icons.copy, color: theme.colorScheme.primary),
                tooltip: '复制路径',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _downloadDir));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('下载目录已复制到剪贴板'), duration: Duration(seconds: 2)),
                  );
                },
              ),
            ),

          const Divider(),

          // 关于
          _SectionHeader(title: '关于'),
          ListTile(
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            title: const Text('版本'),
            subtitle: Text(AppConstants.version),
          ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
            title: const Text('日志'),
            subtitle: const Text('查看应用运行日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLogDialog(context),
          ),
        ],
      ),
    );
  }

  void _showLogDialog(BuildContext context) {
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
                  onPressed: () {
                    _loadLogs();
                  },
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
