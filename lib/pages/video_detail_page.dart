import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video.dart';
import '../providers/search_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class VideoDetailPage extends StatefulWidget {
  final String bvid;

  const VideoDetailPage({super.key, required this.bvid});

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  String? _selectedFormatId;
  String? _selectedQuality;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() {
    final provider = context.read<SearchProvider>();
    // 清除旧数据，避免显示上一个视频的残留内容
    provider.clearDetail();
    provider.loadDetail(widget.bvid);
  }

  /// 根据优先级选择最佳画质（基于 quality int 而非中文描述，避免 contains 误匹配）
  void _selectBestQuality(BiliVideoDetail detail, SettingsProvider settings) {
    if (detail.formats.isEmpty) return;

    // 用户首选画质（文本）映射到 quality int 列表（一个文本可能对应多个 id）
    final preferredIds = _preferredQualityIds(settings.preferredQuality);
    final orderedIds = <int>[
      ...preferredIds,
      ...AppConstants.qualityIdPriority.where((id) => !preferredIds.contains(id)),
    ];

    // 详情接口返回的 formatId 是 quality int 的字符串形式（80/120 等）
    final available = <int, BiliVideoFormat>{};
    for (final f in detail.formats) {
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

    // 兜底：选择最高 quality 的
    if (chosen == null) {
      final sorted = available.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      if (sorted.isNotEmpty) {
        chosen = sorted.first.value;
      } else {
        chosen = detail.formats.first;
      }
    }

    if (_selectedFormatId != chosen!.formatId || _selectedQuality != chosen!.quality) {
      setState(() {
        _selectedFormatId = chosen!.formatId;
        _selectedQuality = chosen!.quality;
      });
    }
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
      appBar: AppBar(title: const Text('视频详情')),
      body: Consumer<SearchProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
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
            // 详情未加载完成或 bvid 不匹配
            if (!provider.isLoading && detail == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    const Text('无法加载视频详情'),
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
            return const Center(child: CircularProgressIndicator());
          }
          return _buildDetail(detail);
        },
      ),
    );
  }

  Widget _buildDetail(BiliVideoDetail detail) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    // 初始化画质选择
    if (_selectedFormatId == null) {
      _selectBestQuality(detail, settings);
    }

    final bestFormatId = _selectedFormatId ?? '80';
    final bestQuality = _selectedQuality ?? '1080P';
    final pubdateText = _formatPubdateText(detail.pubdate);

    return ListView(
      children: [
        // 封面
        Stack(
          children: [
            Image.network(
              detail.pic,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: theme.colorScheme.surfaceVariant,
                child: const Icon(Icons.broken_image, size: 64),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(detail.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
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
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(detail.uploader, style: theme.textTheme.bodyMedium),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),

        const Divider(),

        // 画质选择
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('画质选择', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  // 显式下拉，给"画质选择"一个一目了然的入口
                  if (detail.formats.isNotEmpty)
                    DropdownButton<String>(
                      value: _selectedFormatId,
                      isDense: true,
                      items: detail.formats
                          .map((f) => DropdownMenuItem(
                                value: f.formatId,
                                child: Text(
                                  f.quality,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final f = detail.formats.firstWhere((e) => e.formatId == value);
                        setState(() {
                          _selectedFormatId = f.formatId;
                          _selectedQuality = f.quality;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: detail.formats.map((f) => ChoiceChip(
                  label: Text(f.quality, style: const TextStyle(fontSize: 12)),
                  selected: f.formatId == _selectedFormatId,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFormatId = f.formatId;
                        _selectedQuality = f.quality;
                      });
                    }
                  },
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                '当前画质：$bestQuality（部分高画质需登录大会员）',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
}
