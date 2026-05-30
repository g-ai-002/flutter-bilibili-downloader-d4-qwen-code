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
  @override
  void initState() {
    super.initState();
    context.read<SearchProvider>().loadDetail(widget.bvid);
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
          if (detail == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(provider.error ?? '无法加载视频详情'),
                ],
              ),
            );
          }
          return _buildDetail(detail);
        },
      ),
    );
  }

  Widget _buildDetail(BiliVideoDetail detail) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final preferredQuality = settings.preferredQuality;

    // 选择最佳画质
    String bestFormatId = '80'; // 默认 1080P
    String bestQuality = '1080P';
    for (final q in AppConstants.qualityPriority) {
      final match = detail.formats.where((f) => f.quality.contains(q)).toList();
      if (match.isNotEmpty) {
        bestFormatId = match.first.formatId;
        bestQuality = match.first.quality;
        break;
      }
    }
    if (detail.formats.isNotEmpty) {
      bestFormatId = detail.formats.first.formatId;
      bestQuality = detail.formats.first.quality;
    }

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

        // 标题
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
          child: Row(
            children: [
              Text('画质选择', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              ...detail.formats.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f.quality, style: const TextStyle(fontSize: 12)),
                  selected: f.formatId == bestFormatId,
                  onSelected: (_) {},
                  visualDensity: VisualDensity.compact,
                ),
              )),
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
