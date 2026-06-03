import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/download_job.dart';
import '../providers/download_provider.dart';
import '../services/file_system_service.dart';
import 'video_detail_page.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DownloadJob> _filteredJobs(List<DownloadJob> jobs) {
    if (_searchQuery.isEmpty) return jobs;
    return jobs
        .where((j) =>
            j.videoName.contains(_searchQuery) ||
            j.episodeName.contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '搜索下载任务...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    isDense: true,
                    constraints: const BoxConstraints(maxHeight: 34),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 4),
              Consumer<DownloadProvider>(
                builder: (context, provider, _) {
                  final hasFailed = provider.failedJobs.isNotEmpty;
                  final hasCompleted = provider.completedJobs.isNotEmpty;
                  final hasCanceled = provider.jobs
                      .where((j) => j.status == DownloadStatus.canceled)
                      .isNotEmpty;
                  final hasQueued = provider.jobs
                      .where((j) => j.status == DownloadStatus.queued)
                      .isNotEmpty;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasFailed)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          iconSize: 24,
                          tooltip: '重试全部',
                          onPressed: provider.retryAll,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: PopupMenuButton<String>(
                          tooltip: '批量清理',
                          icon: const Icon(Icons.cleaning_services_outlined),
                          iconSize: 24,
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          onSelected: (value) {
                          switch (value) {
                            case 'completed':
                              provider.clearCompleted();
                              break;
                            case 'failed':
                              provider.clearFailed();
                              break;
                            case 'canceled':
                              provider.clearCanceled();
                              break;
                            case 'queued':
                              provider.clearQueued();
                              break;
                            case 'all':
                              provider.clearCompleted();
                              provider.clearFailed();
                              provider.clearCanceled();
                              provider.clearQueued();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (hasCompleted)
                            const PopupMenuItem(
                              value: 'completed',
                              child: Text('清除已完成任务'),
                            ),
                          if (hasFailed)
                            const PopupMenuItem(
                              value: 'failed',
                              child: Text('清除失败任务'),
                            ),
                          if (hasCanceled)
                            const PopupMenuItem(
                              value: 'canceled',
                              child: Text('清除已取消任务'),
                            ),
                          if (hasQueued)
                            const PopupMenuItem(
                              value: 'queued',
                              child: Text('清除排队中任务'),
                            ),
                          const PopupMenuItem(
                            value: 'all',
                            child: Text('清除全部'),
                          ),
                        ],
                      ),
                    ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, provider, _) {
          final jobs = _filteredJobs(provider.jobs);
          if (provider.jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('暂无下载任务', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('搜索视频并添加到下载队列',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            );
          }
          if (jobs.isEmpty && _searchQuery.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off,
                      size: 48, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('未找到匹配的下载任务',
                      style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _DownloadJobCard(key: ValueKey(job.id), job: job);
            },
          );
        },
      ),
    );
  }
}

class _DownloadJobCard extends StatelessWidget {
  final DownloadJob job;

  const _DownloadJobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = job.status == DownloadStatus.downloading;
    final isCompleted = job.status == DownloadStatus.completed;
    final isFailed = job.status == DownloadStatus.failed;
    final isCanceled = job.status == DownloadStatus.canceled;
    final isQueued = job.status == DownloadStatus.queued;

    Color statusColor;
    IconData statusIcon;
    switch (job.status) {
      case DownloadStatus.downloading:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.downloading;
        break;
      case DownloadStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case DownloadStatus.failed:
        statusColor = theme.colorScheme.error;
        statusIcon = Icons.error;
        break;
      case DownloadStatus.canceled:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case DownloadStatus.queued:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 封面缩略图
                if (job.pic != null && job.pic!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        job.pic!,
                        width: 120,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 120,
                          height: 75,
                          color: theme.colorScheme.surfaceVariant,
                          child: Icon(Icons.broken_image, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.videoName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (job.episodeName != job.videoName)
                        Text(
                          job.episodeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(job.status.label,
                    style: TextStyle(color: statusColor, fontSize: 12)),
              ],
            ),
            if (isActive || isQueued) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: job.progress > 0 ? job.progress / 100 : null,
                backgroundColor: theme.colorScheme.surfaceVariant,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${job.progress}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (job.speedText.isNotEmpty)
                    Text(
                      job.speedText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (job.elapsedTime.isNotEmpty)
                      Text('已用时 ${job.elapsedTime}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          )),
                    if (job.remainingTime.isNotEmpty) ...[
                      if (job.elapsedTime.isNotEmpty) const SizedBox(width: 8),
                      Text(job.remainingTime,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                          )),
                    ],
                  ],
                ),
              ],
            ],
            if (isFailed && job.error != null) ...[
              const SizedBox(height: 4),
              Text(
                job.error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            // 已完成任务显示元数据
            if (isCompleted) ...[
              const SizedBox(height: 8),
              _buildMetadataRow(context, theme, job),
            ],
            // 已完成任务显示文件路径和时间
            if (isCompleted && job.filePath != null && job.filePath!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPathRow(context, theme, '视频', job.filePath!),
                    if (job.audioPath != null && job.audioPath!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _buildPathRow(context, theme, '音频', job.audioPath!),
                      const SizedBox(height: 4),
                      Text(
                        '提示：本次未成功合并视频/音频轨。可尝试重新下载以触发自动合并。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    if (job.totalDuration.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '下载用时: ${job.downloadDuration}'
                        '${job.mergeDuration.isNotEmpty ? ' | 合并用时: ${job.mergeDuration}' : ''}'
                        ' | 总用时: ${job.totalDuration}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 下载中：取消 + 删除
                if (isActive) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('取消'),
                    onPressed: () =>
                        context.read<DownloadProvider>().cancel(job.id),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    onPressed: () =>
                        context.read<DownloadProvider>().remove(job.id),
                  ),
                ],
                // 排队中：取消 + 删除
                if (isQueued) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('取消'),
                    onPressed: () =>
                        context.read<DownloadProvider>().cancel(job.id),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    onPressed: () =>
                        context.read<DownloadProvider>().remove(job.id),
                  ),
                ],
                // 失败/取消：删除 + 失败时可重试
                if (isFailed) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重试'),
                    onPressed: () =>
                        context.read<DownloadProvider>().retry(job.id),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    onPressed: () =>
                        context.read<DownloadProvider>().remove(job.id),
                  ),
                ],
                if (isCanceled)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    onPressed: () =>
                        context.read<DownloadProvider>().remove(job.id),
                  ),
                if (isCompleted &&
                    job.filePath != null &&
                    job.filePath!.isNotEmpty &&
                    (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('打开所在目录'),
                    onPressed: () async {
                      final ok = await FileSystemService.instance
                          .revealInFileManager(job.filePath!);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('当前平台不支持打开文件管理器')),
                        );
                      }
                    },
                  ),
                if (isCompleted &&
                    job.filePath != null &&
                    job.filePath!.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.play_circle_outline, size: 16),
                    label: const Text('播放'),
                    onPressed: () async {
                      final ok = await FileSystemService.instance
                          .openWithSystemPlayer(job.filePath!);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('无法打开系统播放器')),
                        );
                      }
                    },
                  ),
                if (isCompleted)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    onPressed: () =>
                        context.read<DownloadProvider>().remove(job.id),
                  ),
                if (job.bvid.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: const Text('详情'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoDetailPage(bvid: job.bvid),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(
    BuildContext context,
    ThemeData theme,
    DownloadJob job,
  ) {
    final parts = <String>[];
    if (job.durationSeconds != null && job.durationSeconds! > 0) {
      parts.add(job.videoDurationText);
    }
    if (job.fileSize != null && job.fileSize! > 0) {
      parts.add(_formatFileSize(job.fileSize!));
    }
    if (job.videoWidth != null && job.videoHeight != null) {
      parts.add('${job.videoWidth}x${job.videoHeight}');
    }
    if (job.fps != null) {
      parts.add('${job.fps!.toStringAsFixed(1)} fps');
    }
    if (job.videoCodec != null && job.videoCodec!.isNotEmpty) {
      parts.add('视频: ${job.videoCodec}');
    }
    if (job.audioCodec != null && job.audioCodec!.isNotEmpty) {
      parts.add('音频: ${job.audioCodec}');
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: parts.map((p) => Text(
          p,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        )).toList(),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildPathRow(
    BuildContext context,
    ThemeData theme,
    String label,
    String path,
  ) {
    return Row(
      children: [
        Icon(Icons.insert_drive_file,
            size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text('$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            )),
        Expanded(
          child: Text(
            path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.copy, size: 14, color: theme.colorScheme.primary),
          tooltip: '复制路径',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: path));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('路径已复制到剪贴板'),
                  duration: Duration(seconds: 2)),
            );
          },
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }
}
