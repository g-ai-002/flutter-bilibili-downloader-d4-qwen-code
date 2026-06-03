import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../providers/search_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import 'uploader_videos_page.dart';

class VideoDetailPage extends StatefulWidget {
  final String bvid;

  const VideoDetailPage({super.key, required this.bvid});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {

  @override
  void initState() {
    super.initState();
    // 延迟到首帧之后发起加载，确保 Consumer 已挂载并注册了 listener，
    // 避免 notifyListeners 在 listener 注册前被调用而导致 UI 永不刷新。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadDetail();
    });
  }

  void _loadDetail() {
    final provider = context.read<SearchProvider>();
    // 清除旧数据，避免显示上一个视频的残留内容
    provider.clearDetail();
    provider.loadDetail(widget.bvid);
  }

  /// 根据优先级计算最佳画质，返回 (formatId, quality)。
  /// 纯计算，无副作用，可在 build 阶段安全调用。
  ({String formatId, String quality}) _computeBestQuality(
    BiliVideoDetail detail,
    SettingsProvider settings,
  ) {
    final formats = detail.formats.isEmpty
        ? _defaultFormats()
        : detail.formats;

    if (formats.isEmpty) {
      return (formatId: '80', quality: '1080P');
    }

    final preferredIds = _preferredQualityIds(settings.preferredQuality);
    final orderedIds = <int>[
      ...preferredIds,
      ...AppConstants.qualityIdPriority.where((id) => !preferredIds.contains(id)),
    ];

    final available = <int, BiliVideoFormat>{};
    for (final f in formats) {
      final id = int.tryParse(f.formatId);
      if (id != null) available[id] = f;
    }

    BiliVideoFormat? chosen;
    for (final id in orderedIds) {
      if (available.containsKey(id)) {
        chosen = available[id];
        break;
      }
    }

    if (chosen == null) {
      final sorted = available.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      if (sorted.isNotEmpty) {
        chosen = sorted.first.value;
      } else {
        chosen = formats.first;
      }
    }

    return (formatId: chosen!.formatId, quality: chosen!.quality);
  }

  /// 默认画质列表（API 返回空时的兜底选项）
  List<BiliVideoFormat> _defaultFormats() {
    return const [
      BiliVideoFormat(formatId: '120', ext: 'mp4', quality: '4K', hasVideo: true, hasAudio: true),
      BiliVideoFormat(formatId: '116', ext: 'mp4', quality: '1080P60', hasVideo: true, hasAudio: true),
      BiliVideoFormat(formatId: '80', ext: 'mp4', quality: '1080P', hasVideo: true, hasAudio: true),
      BiliVideoFormat(formatId: '64', ext: 'mp4', quality: '720P', hasVideo: true, hasAudio: true),
      BiliVideoFormat(formatId: '32', ext: 'mp4', quality: '480P', hasVideo: true, hasAudio: true),
      BiliVideoFormat(formatId: '16', ext: 'mp4', quality: '360P', hasVideo: true, hasAudio: true),
    ];
  }

  /// 将用户首选画质文本映射为可能的 quality id 列表
  List<int> _preferredQualityIds(String label) {
    switch (label) {
      case '4K':
        return [120];
      case '1080P+':
        return [112, 116]; // 1080P+ 与 1080P60 等同看待
      case '1080P':
        return [80, 116, 112];
      case '720P':
        return [64, 74];
      case '480P':
        return [32];
      case '360P':
        return [16];
      default:
        return const [];
    }
  }

  String _formatPubdateText(int pubdate) {
    if (pubdate <= 0) return '';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(pubdate * 1000);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Consumer<SearchProvider>(
          builder: (context, provider, _) {
            final detail = provider.detail;
            if (detail != null && detail.bvid == widget.bvid) {
              return Text(
                '${detail.title} - ${detail.uploader}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            }
            return const Text('视频详情');
          },
        ),
      ),
      body: Consumer<SearchProvider>(
        builder: (context, provider, _) {
          final detail = provider.detail;
          // 确保加载的是当前请求的视频
          if (detail == null || detail.bvid != widget.bvid) {
            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text(provider.error!),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                      onPressed: _loadDetail,
                    ),
                  ],
                ),
              );
            }
            // 加载中显示非阻塞骨架，不遮罩整个界面
            return _buildLoadingSkeleton();
          }
          return _buildDetail(detail);
        },
      ),
    );
  }

  /// 非阻塞加载骨架——不遮罩界面，用户可随时返回
  Widget _buildLoadingSkeleton() {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Container(
          height: 200,
          color: theme.colorScheme.surfaceVariant,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '正在加载视频信息...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetail(BiliVideoDetail detail) {
    final theme = Theme.of(context);
    final settings = context.read<SettingsProvider>();

    // 按设置中的首选画质自动选择，不再提供手动切换 UI
    final best = _computeBestQuality(detail, settings);
    final bestFormatId = best.formatId;
    final bestQuality = best.quality;
    final pubdateText = _formatPubdateText(detail.pubdate);

    return ListView(
      cacheExtent: 100000,
      children: [
          // 封面
          AspectRatio(
            aspectRatio: 120 / 75,
            child: Image.network(
              detail.pic,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: theme.colorScheme.surfaceVariant,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: theme.colorScheme.surfaceVariant,
                child: const Icon(Icons.broken_image, size: 64),
              ),
            ),
          ),

          // 标题与元信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // 播放量 · 时长
                Row(
                  children: [
                    if (detail.viewCount > 0) ...[
                      Icon(Icons.play_circle_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(_formatViewCount(detail.viewCount), style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.access_time, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(_formatDuration(detail.duration), style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: detail.uploaderMid > 0
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UploaderVideosPage(
                                    mid: detail.uploaderMid,
                                    name: detail.uploader,
                                    face: detail.uploaderFace,
                                  ),
                                ),
                              )
                          : null,
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            detail.uploader,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.videocam, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${detail.episodes.length} 集', style: theme.textTheme.bodyMedium),
                  ],
                ),
                if (pubdateText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('发布时间: $pubdateText', style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text('简介', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  detail.desc.isEmpty ? '暂无简介' : detail.desc,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),

          const Divider(),

          // 分集列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '分集列表 (${detail.episodes.length})',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),

          ...detail.episodes.map((ep) => ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text('${ep.page}', style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
            ),
            title: Text(ep.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('BV: ${ep.bvid}', style: theme.textTheme.bodySmall),
            trailing: FilledButton.tonalIcon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('下载'),
              onPressed: () => _startDownload(detail, ep, bestFormatId, bestQuality),
            ),
          )),

          // 一键下载全部
          if (detail.episodes.length > 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                icon: const Icon(Icons.download),
                label: Text('下载全部 (${detail.episodes.length} 集)'),
                onPressed: () {
                  for (final ep in detail.episodes) {
                    _startDownload(detail, ep, bestFormatId, bestQuality);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加 ${detail.episodes.length} 个下载任务')),
                  );
                },
              ),
            ),
          const SizedBox(height: 32),
      ],
    );
  }

  void _startDownload(BiliVideoDetail detail, BiliEpisode ep, String formatId, String quality) {
    context.read<DownloadProvider>().addJob(
      videoName: detail.title,
      episodeName: ep.name,
      bvid: ep.bvid,
      cid: ep.cid ?? 0,
      formatId: formatId,
      quality: quality,
      pic: detail.pic,
      durationSeconds: detail.duration > 0 ? detail.duration : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加下载任务: ${ep.name}')),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatViewCount(int count) {
    if (count >= 10000) {
      final wan = count / 10000;
      return '${wan.toStringAsFixed(wan >= 100 ? 0 : 1)}万播放';
    }
    return '$count 播放';
  }
}
