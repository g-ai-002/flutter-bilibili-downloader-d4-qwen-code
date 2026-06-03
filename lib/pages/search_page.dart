import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../providers/search_provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import 'video_detail_page.dart';
import 'login_page.dart';
import 'uploader_videos_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

enum SearchType { video, uploader }

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  late final TabController _tabController;
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSearchHistory();
    _scrollController.addListener(_onScroll);
    _tabController.addListener(_onTabChanged);
  }

  SearchType get _searchType =>
      _tabController.index == 0 ? SearchType.video : SearchType.uploader;

  int _previousTabIndex = 0;

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == _previousTabIndex) return;
    _previousTabIndex = _tabController.index;
    setState(() {});
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      _search(keyword);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<SearchProvider>();
      if (_searchType == SearchType.video) {
        provider.loadMore();
      } else {
        provider.loadMoreUploaders();
      }
    }
  }

  Future<void> _loadSearchHistory() async {
    final storage = await StorageService.instance;
    final history = await storage.getSearchHistory();
    final keyword = storage.searchKeyword;
    if (mounted) {
      _searchController.text = keyword;
      setState(() => _searchHistory = history);
    }
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    _focusNode.unfocus();

    final provider = context.read<SearchProvider>();
    if (_searchType == SearchType.video) {
      provider.search(keyword);
    } else {
      provider.searchUploaders(keyword);
    }

    final storage = await StorageService.instance;
    storage.searchKeyword = keyword;
    await storage.addSearchHistory(keyword);
    if (!mounted) return;
    setState(() {
      _searchHistory.remove(keyword);
      _searchHistory.insert(0, keyword);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final provider = context.read<SearchProvider>();
          if (_searchType == SearchType.video) {
            await provider.search(provider.keyword);
          } else {
            await provider.searchUploaders(provider.keyword);
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Consumer<SettingsProvider>(
                          builder: (context, settings, _) {
                            final user = settings.userInfo;
                            return user != null && user.face.isNotEmpty
                                ? CircleAvatar(
                                    radius: 16,
                                    backgroundImage: NetworkImage(user.face),
                                  )
                                : CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        theme.colorScheme.surfaceVariant,
                                    child: Icon(Icons.person,
                                        size: 18,
                                        color: theme
                                            .colorScheme.onSurfaceVariant),
                                  );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: theme.colorScheme.outline, width: 0.5),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '搜索...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withOpacity(0.6),
                            ),
                            prefixIcon:
                                const Icon(Icons.search, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.search,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: _search,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.qr_code),
                      tooltip: '扫码登录',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginPage()),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '视频'),
                  Tab(text: 'UP主'),
                ],
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 14),
                indicatorSize: TabBarIndicatorSize.label,
              ),
            ),
            // 内容区域
            ..._buildContent(theme),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(ThemeData theme) {
    return [
      Consumer<SearchProvider>(
        builder: (context, provider, _) {
          // 加载中
          if (provider.isLoading &&
              provider.results.isEmpty &&
              provider.uploaderResults.isEmpty) {
            return const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          // 错误
          if (provider.error != null &&
              provider.results.isEmpty &&
              provider.uploaderResults.isEmpty) {
            return SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(provider.error!,
                        style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            );
          }

          // UP主搜索结果
          if (_searchType == SearchType.uploader &&
              provider.uploaderResults.isNotEmpty) {
            return _buildUploaderSliverList(provider, theme);
          }

          // 视频搜索结果
          if (_searchType == SearchType.video &&
              provider.results.isNotEmpty) {
            return _buildVideoSliverList(provider, theme);
          }

          // 搜索历史
          if (_searchHistory.isNotEmpty) {
            return _buildSearchHistorySliverList(theme);
          }

          // 空状态
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('搜索你想下载的 Bilibili 视频',
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('支持搜索视频标题和 UP 主',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }

  SliverList _buildVideoSliverList(
      SearchProvider provider, ThemeData theme) {
    return SliverList.builder(
      itemCount: provider.results.length + (provider.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final video = provider.results[index];
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
    );
  }

  SliverList _buildUploaderSliverList(
      SearchProvider provider, ThemeData theme) {
    return SliverList.builder(
      itemCount:
          provider.uploaderResults.length + (provider.hasMoreUploaders ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= provider.uploaderResults.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final uploader = provider.uploaderResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UploaderVideosPage.fromUploader(uploader),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(uploader.face),
                    child: uploader.face.isEmpty
                        ? Icon(Icons.person,
                            color: theme.colorScheme.onSurfaceVariant)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uploader.name,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '粉丝: ${uploader.fans}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (uploader.sign.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            uploader.sign,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  SliverList _buildSearchHistorySliverList(ThemeData theme) {
    return SliverList.builder(
      itemCount: _searchHistory.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
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
          );
        }
        final keyword = _searchHistory[index - 1];
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
          onTap: () {
            _searchController.text = keyword;
            _search(keyword);
          },
        );
      },
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
                  cacheWidth: 240,
                  cacheHeight: 150,
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
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
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
                        Icon(Icons.play_circle_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(video.viewCount,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(video.duration,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                    if (video.pubdate.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              video.pubdate,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
