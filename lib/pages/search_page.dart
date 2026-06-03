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
  late final TabController _tabController;
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSearchHistory();
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
    _tabController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildSearchBox() {
    final theme = Theme.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outline, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
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
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '搜索...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant
                        .withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant,
                  prefixIcon:
                      const Icon(Icons.search, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 0),
                  isDense: true,
                  constraints: const BoxConstraints(maxHeight: 34),
                ),
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: _search,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 44,
              titleSpacing: 0,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              title: _buildSearchBox(),
            ),
            SliverPersistentHeader(
              pinned: false,
              floating: true,
              delegate: _TabBarDelegate(
                tabBar: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '视频'),
                    Tab(text: 'UP主'),
                  ],
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorColor: theme.colorScheme.primary,
                  dividerColor: Colors.transparent,
                  tabAlignment: TabAlignment.center,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                ),
                borderColor: theme.colorScheme.outline,
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildVideoTab(),
            _buildUploaderTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoTab() {
    return Consumer<SearchProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.results.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null && provider.results.isEmpty) {
          return _buildErrorWidget(provider.error!);
        }
        if (provider.results.isNotEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.search(provider.keyword),
            child: _buildVideoList(provider),
          );
        }
        return _buildPreSearchContent();
      },
    );
  }

  Widget _buildUploaderTab() {
    return Consumer<SearchProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.uploaderResults.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null && provider.uploaderResults.isEmpty) {
          return _buildErrorWidget(provider.error!);
        }
        if (_searchType == SearchType.uploader &&
            provider.uploaderResults.isNotEmpty) {
          return RefreshIndicator(
            onRefresh: () => provider.searchUploaders(provider.keyword),
            child: _buildUploaderList(provider),
          );
        }
        return _buildPreSearchContent();
      },
    );
  }

  Widget _buildPreSearchContent() {
    if (_searchHistory.isNotEmpty) {
      return _buildSearchHistoryList();
    }
    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
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
    );
  }

  Widget _buildErrorWidget(String error) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(error, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildVideoList(SearchProvider provider) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          provider.loadMore();
        }
        return false;
      },
      child: ListView.builder(
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
      ),
    );
  }

  Widget _buildUploaderList(SearchProvider provider) {
    final theme = Theme.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
          provider.loadMoreUploaders();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: provider.uploaderResults.length +
            (provider.hasMoreUploaders ? 1 : 0),
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
                  builder: (_) =>
                      UploaderVideosPage.fromUploader(uploader),
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
      ),
    );
  }

  Widget _buildSearchHistoryList() {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: _searchHistory.length + 1,
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

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color borderColor;

  _TabBarDelegate({required this.tabBar, required this.borderColor});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: tabBar,
    );
  }

  @override
  double get maxExtent => 40;

  @override
  double get minExtent => 40;

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar || borderColor != oldDelegate.borderColor;
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
