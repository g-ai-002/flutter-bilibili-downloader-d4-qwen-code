import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../providers/search_provider.dart';
import '../services/log_service.dart';
import 'video_detail_page.dart';

/// UP 主视频列表页（支持分页加载）
class UploaderVideosPage extends StatefulWidget {
  final int mid;
  final String name;
  final String face;

  /// 从已有 BiliUploader 构造
  factory UploaderVideosPage.fromUploader(BiliUploader uploader) {
    return UploaderVideosPage(
      mid: uploader.mid,
      name: uploader.name,
      face: uploader.face,
    );
  }

  const UploaderVideosPage({
    super.key,
    required this.mid,
    required this.name,
    this.face = '',
  });

  @override
  State<UploaderVideosPage> createState() => _UploaderVideosPageState();
}

class _UploaderVideosPageState extends State<UploaderVideosPage> {
  final _scrollController = ScrollController();
  List<BiliVideo> _videos = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    final api = context.read<SearchProvider>().api;
    if (api == null) {
      setState(() {
        _loading = false;
        _error = 'API 未初始化';
      });
      return;
    }
    try {
      final list = await api.getUploaderVideos(widget.mid, page: 1);
      if (!mounted) return;
      setState(() {
        _videos = list;
        _loading = false;
        _page = 1;
        _hasMore = list.length >= 30;
      });
    } catch (e) {
      LogService.error('加载 UP 主视频列表失败', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final api = context.read<SearchProvider>().api;
    if (api == null) return;
    _loadingMore = true;
    setState(() {});

    try {
      final more = await api.getUploaderVideos(widget.mid, page: _page + 1);
      if (!mounted) return;
      setState(() {
        if (more.isEmpty) {
          _hasMore = false;
        } else {
          _videos.addAll(more);
          _page++;
          _hasMore = more.length >= 30;
        }
        _loadingMore = false;
      });
    } catch (e) {
      LogService.error('加载更多 UP 主视频失败', e);
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.face.isNotEmpty
                  ? NetworkImage(widget.face)
                  : null,
              child: widget.face.isEmpty ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
            ),
          ],
        ),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('该 UP 主暂无投稿'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _videos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _videos.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final v = _videos[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VideoDetailPage(bvid: v.bvid)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        v.pic,
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
                            v.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.play_circle_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(v.viewCount, style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                              const SizedBox(width: 12),
                              Icon(Icons.access_time, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(v.duration, style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              )),
                            ],
                          ),
                          if (v.pubdate.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 12, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    v.pubdate,
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
        },
      ),
    );
  }
}
