import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/download_job.dart';
import '../providers/download_provider.dart';
import '../services/file_system_service.dart';

class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        actions: [
          Consumer<DownloadProvider>(
            builder: (context, provider, _) {
              final hasFailed = provider.failedJobs.isNotEmpty;
              final hasCompleted = provider.completedJobs.isNotEmpty;
              return Row(
                children: [
                  if (hasFailed)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: '重试全部',
                      onPressed: provider.retryAll,
                    ),
                  if (hasCompleted)
                    IconButton(
                      icon: const Icon(Icons.clear_all),
                      tooltip: '清除已完成',
                      onPressed: provider.clearCompleted,
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, provider, _) {
          if (provider.jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_outlined, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('暂无下载任务', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('搜索视频并添加到下载队列', style: theme.textTheme.bodySmall),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.jobs.length,
            itemBuilder: (context, index) {
              final job = provider.jobs[index];
              return _DownloadJobCard(job: job);
            },
          );
        },
      ),
    );
  }
}

class _DownloadJobCard extends StatelessWidget {
  final DownloadJob job;

  const _DownloadJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = job.status == DownloadStatus.downloading;
    final isCompleted = job.status == DownloadStatus.completed;
    final isFailed = job.status == DownloadStatus.failed;
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
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.videoName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
                Text(job.status.label, style: TextStyle(color: statusColor, fontSize: 12)),
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
            ],
            if (isFailed && job.error != null) ...[
              const SizedBox(height: 4),
              Text(
                job.error!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            // 已完成任务显示文件路径
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
                        '提示：当前未合并视频/音频轨。Windows/桌面端安装系统 ffmpeg 后重新下载将自动合并。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
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
                if (isFailed)
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重试'),
                    onPressed: () => context.read<DownloadProvider>().retry(job.id),
                  ),
                if (isQueued)
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('取消'),
                    onPressed: () => context.read<DownloadProvider>().cancel(job.id),
                  ),
                if (isCompleted && job.filePath != null && job.filePath!.isNotEmpty &&
                    (Platform.isWindows || Platform.isMacOS || Platform.isLinux))
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('打开所在目录'),
                    onPressed: () async {
                      final ok = await FileSystemService.instance
                          .revealInFileManager(job.filePath!);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('当前平台不支持打开文件管理器')),
                        );
                      }
                    },
                  ),
                if (isCompleted)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    onPressed: () => context.read<DownloadProvider>().remove(job.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathRow(
    BuildContext context,
    ThemeData theme,
    String label,
    String path,
  ) {
    return Row(
      children: [
        Icon(Icons.insert_drive_file, size: 14, color: theme.colorScheme.primary),
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
              const SnackBar(content: Text('路径已复制到剪贴板'), duration: Duration(seconds: 2)),
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
