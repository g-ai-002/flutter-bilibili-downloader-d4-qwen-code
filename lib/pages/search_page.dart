import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../providers/search_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import 'video_detail_page.dart';
import 'login_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final storage = await StorageService.instance;
    final history = await storage.getSearchHistory();
    if (mounted) {
      setState(() => _searchHistory = history);
    }
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    _focusNode.unfocus();

    final storage = await StorageService.instance;
    await storage.addSearchHistory(keyword);

    if (!mounted) return;
    context.read<SearchProvider>().search(keyword);
    // 避免重复
    _searchHistory.remove(keyword);
    setState(() => _searchHistory.insert(0, keyword));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: '搜索 Bilibili 视频...',
            border: InputBorder.none,
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _search(_searchController.text),
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: '扫码登录',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
          ),
        ],
      ),
      body: Consumer<SearchProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(provider.error!, style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }
          if (provider.results.isNotEmpty) {
            return _buildResultsList(provider.results);
          }
          if (_searchHistory.isNotEmpty) {
            return _buildSearchHistory();
          }
          return _buildEmptyState();
        },
      ),
    );
  }

  Widget _buildResultsList(List<BiliVideo> results) {
    return RefreshIndicator(
      onRefresh: () async {
        final provider = context.read<SearchProvider>();
        await provider.search(provider.keyword);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final video = results[index];
          return _VideoCard(
            video: video,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoDetailPage(bvid: video.bvid),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchHistory() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('搜索历史', style: theme.textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空'),
                onPressed: () async {
                  final storage = await StorageService.instance;
                  await storage.clearSearchHistory();
                  setState(() => _searchHistory.clear());
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final keyword = _searchHistory[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(keyword),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    final storage = await StorageService.instance;
                    await storage.removeSearchHistory(keyword);
                    setState(() => _searchHistory.remove(keyword));
                  },
                ),
                onTap: () => _search(keyword),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('搜索你想下载的 Bilibili 视频', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('支持搜索视频标题和 UP 主', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final BiliVideo video;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.pic,
                  width: 120,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 120,
                    height: 75,
                    color: theme.colorScheme.surfaceVariant,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            video.uploader,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(video.viewCount, style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(video.duration, style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
