package com.bilibili.downloader

import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.bilibili.downloader/ffmpeg"
        private const val TAG = "BilibiliDownloader"
        private const val MERGE_TIMEOUT_SECONDS = 36000L // 10 小时
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "mergeAv") {
                val videoPath = call.argument<String>("videoPath")
                val audioPath = call.argument<String>("audioPath")
                val outputPath = call.argument<String>("outputPath")

                if (videoPath == null || audioPath == null || outputPath == null) {
                    result.error("INVALID_ARGS", "videoPath, audioPath, outputPath must not be null", null)
                    return@setMethodCallHandler
                }

                Log.i(TAG, "收到合并请求: video=$videoPath, audio=$audioPath, output=$outputPath")

                // 在主线程上使用 Media3 Transformer（Media3 要求在创建线程上执行所有操作）
                mergeAvWithTransformer(videoPath, audioPath, outputPath) { success, mergedPath, errorMsg ->
                    if (success && mergedPath != null) {
                        result.success(mergedPath)
                        Log.i(TAG, "Media3 Transformer 合并成功，返回路径: $mergedPath")
                    } else {
                        result.error("MERGE_FAILED", errorMsg ?: "Media3 Transformer 合并未知错误", null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * 使用 Jetpack Media3 Transformer 合并视频轨和音频轨。
     *
     * 关键要求：Transformer 必须在主线程（拥有 Looper 的线程）上创建和调用所有方法。
     * Media3 内部使用 Handler 进行线程调度，因此调用线程必须拥有 Looper。
     *
     * 原理：Transformer 通过 Composition 组合视频序列和音频序列，
     * 启用 transmuxing 优化以优先使用 passthrough 模式（不解码/不重编码），
     * 格式不兼容时才回退到转码。合并后自动检测实际使用的模式并记录日志。
     *
     * @param videoPath  视频文件路径
     * @param audioPath  音频文件路径
     * @param outputPath 合并输出文件路径
     * @param callback   结果回调 (success, outputPath, errorMessage)
     */
    private fun mergeAvWithTransformer(
        videoPath: String,
        audioPath: String,
        outputPath: String,
        callback: (Boolean, String?, String?) -> Unit
    ) {
        val startTimeMs = System.currentTimeMillis()

        val videoFile = File(videoPath)
        val audioFile = File(audioPath)

        // ── 文件存在性检查 ──
        if (!videoFile.exists()) {
            val msg = "视频文件不存在: $videoPath"
            Log.e(TAG, msg)
            callback(false, null, msg)
            return
        }
        if (!audioFile.exists()) {
            val msg = "音频文件不存在: $audioPath"
            Log.e(TAG, msg)
            callback(false, null, msg)
            return
        }

        val videoSize = videoFile.length()
        val audioSize = audioFile.length()
        val totalInputSize = videoSize + audioSize

        // ── 提取输入文件编码信息 ──
        val videoCodecInfo = extractCodecInfo(videoPath)
        val audioCodecInfo = extractCodecInfo(audioPath)

        Log.i(TAG, "╔══════════════════════════════════════════════════════════════╗")
        Log.i(TAG, "║          Media3 Transformer 合并开始                        ║")
        Log.i(TAG, "╠══════════════════════════════════════════════════════════════╣")
        Log.i(TAG, "║ 视频文件 : $videoPath")
        Log.i(TAG, "║   大小   : ${formatFileSize(videoSize)} ($videoSize bytes)")
        Log.i(TAG, "║   编码   : $videoCodecInfo")
        Log.i(TAG, "║ 音频文件 : $audioPath")
        Log.i(TAG, "║   大小   : ${formatFileSize(audioSize)} ($audioSize bytes)")
        Log.i(TAG, "║   编码   : $audioCodecInfo")
        Log.i(TAG, "║ 输入合计 : ${formatFileSize(totalInputSize)}")
        Log.i(TAG, "║ 输出路径 : $outputPath")
        Log.i(TAG, "║ 超时设置 : ${MERGE_TIMEOUT_SECONDS}s")
        Log.i(TAG, "╚══════════════════════════════════════════════════════════════╝")

        // 确保输出目录存在
        val outFile = File(outputPath)
        val parentDir = outFile.parentFile
        if (parentDir != null && !parentDir.exists()) {
            val created = parentDir.mkdirs()
            Log.i(TAG, "创建输出目录: ${parentDir.absolutePath} (success=$created)")
        } else if (parentDir != null) {
            Log.d(TAG, "输出目录已存在: ${parentDir.absolutePath}")
        }

        val context = this
        var transformer: Transformer? = null
        var completed = false

        // 使用 Handler 设置超时
        val timeoutRunnable = Runnable {
            if (!completed) {
                completed = true
                try { transformer?.cancel() } catch (_: Exception) {}
                val elapsed = System.currentTimeMillis() - startTimeMs
                Log.e(TAG, "╔══════════════════════════════════════════════════════════════╗")
                Log.e(TAG, "║          Media3 Transformer 合并超时                        ║")
                Log.e(TAG, "╠══════════════════════════════════════════════════════════════╣")
                Log.e(TAG, "║ 超时阈值 : ${MERGE_TIMEOUT_SECONDS}s")
                Log.e(TAG, "║ 已耗时   : ${formatDuration(elapsed)}")
                Log.e(TAG, "║ 视频     : $videoPath (${formatFileSize(videoSize)})")
                Log.e(TAG, "║ 音频     : $audioPath (${formatFileSize(audioSize)})")
                Log.e(TAG, "║ 输出     : $outputPath (exists=${outFile.exists()})")
                Log.e(TAG, "╚══════════════════════════════════════════════════════════════╝")
                callback(false, null, "Media3 Transformer 合并超时 (${MERGE_TIMEOUT_SECONDS}s)")
            }
        }
        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.postDelayed(timeoutRunnable, TimeUnit.SECONDS.toMillis(MERGE_TIMEOUT_SECONDS))

        try {
            val videoItem = MediaItem.fromUri(videoFile.toURI().toString())
            val audioItem = MediaItem.fromUri(audioFile.toURI().toString())

            // 创建包含视频的序列
            val videoSequence = EditedMediaItemSequence.Builder(
                listOf(EditedMediaItem.Builder(videoItem).build())
            ).build()

            // 创建包含音频的序列
            val audioSequence = EditedMediaItemSequence.Builder(
                listOf(EditedMediaItem.Builder(audioItem).build())
            ).build()

            // 组合两个序列，Transformer 会自动对齐时间戳
            val composition = Composition.Builder(listOf(videoSequence, audioSequence))
                .build()

            // 显式启用 transmuxing 优化：格式兼容时不解码/不重编码，直接复制流
            Log.i(TAG, "正在初始化 Transformer（transmuxing 音视频均已启用）...")
            val builder = Transformer.Builder(context)
                .setTransmuxVideo(true)
                .setTransmuxAudio(true)

            transformer = builder
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(
                        composition: Composition,
                        exportResult: ExportResult
                    ) {
                        if (completed) return
                        completed = true
                        mainHandler.removeCallbacks(timeoutRunnable)

                        val elapsed = System.currentTimeMillis() - startTimeMs

                        // 验证输出文件
                        if (!outFile.exists() || outFile.length() == 0L) {
                            Log.e(TAG, "╔══════════════════════════════════════════════════════════════╗")
                            Log.e(TAG, "║          合并完成但输出文件异常                             ║")
                            Log.e(TAG, "╠══════════════════════════════════════════════════════════════╣")
                            Log.e(TAG, "║ 输出路径   : $outputPath")
                            Log.e(TAG, "║ 文件存在   : ${outFile.exists()}")
                            Log.e(TAG, "║ 文件大小   : ${if (outFile.exists()) outFile.length() else 0}")
                            Log.e(TAG, "║ exportResult.durationMs : ${exportResult.durationMs}")
                            Log.e(TAG, "║ exportResult.fileSizeBytes : ${exportResult.fileSizeBytes}")
                            Log.e(TAG, "╚══════════════════════════════════════════════════════════════╝")
                            callback(false, null, "合并输出文件不存在或为空: $outputPath")
                            return
                        }

                        val outputSize = outFile.length()

                        // 提取输出文件编码信息
                        val outputCodecInfo = extractCodecInfo(outputPath)

                        // 判断是否走了 passthrough 无损模式
                        val isPassthrough = detectPassthrough(
                            videoCodecInfo, audioCodecInfo, outputCodecInfo,
                            totalInputSize, outputSize
                        )

                        val sizeRatio = if (totalInputSize > 0)
                            outputSize.toDouble() / totalInputSize * 100.0
                        else 0.0

                        Log.i(TAG, "╔══════════════════════════════════════════════════════════════╗")
                        Log.i(TAG, "║          Media3 Transformer 合并完成                        ║")
                        Log.i(TAG, "╠══════════════════════════════════════════════════════════════╣")
                        Log.i(TAG, "║ 耗时       : ${formatDuration(elapsed)}")
                        Log.i(TAG, "║ 输出文件   : $outputPath")
                        Log.i(TAG, "║   大小     : ${formatFileSize(outputSize)} ($outputSize bytes)")
                        Log.i(TAG, "║   编码     : $outputCodecInfo")
                        Log.i(TAG, "║   duration : ${exportResult.durationMs}ms")
                        Log.i(TAG, "║ 输入合计   : ${formatFileSize(totalInputSize)}")
                        Log.i(TAG, "║ 大小比率   : ${String.format("%.1f", sizeRatio)}%")
                        Log.i(TAG, "║ 合并模式   : ${if (isPassthrough) "✅ 无损 (passthrough / stream copy)" else "⚠️ 有损 (转码 / transcode)"}")
                        if (!isPassthrough) {
                            Log.w(TAG, "║ 注意       : 合并走了转码路径，可能造成画质/音质损失")
                            Log.w(TAG, "║             输入视频编码: $videoCodecInfo")
                            Log.w(TAG, "║             输入音频编码: $audioCodecInfo")
                            Log.w(TAG, "║             输出编码    : $outputCodecInfo")
                        }
                        Log.i(TAG, "╚══════════════════════════════════════════════════════════════╝")

                        // 合并成功，删除中间文件
                        try {
                            val vDeleted = videoFile.delete()
                            val aDeleted = audioFile.delete()
                            Log.i(TAG, "已删除中间文件: video=$videoPath (deleted=$vDeleted), audio=$audioPath (deleted=$aDeleted)")
                        } catch (e: Exception) {
                            Log.w(TAG, "删除中间文件失败: ${e.message}", e)
                        }

                        callback(true, outputPath, null)
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        if (completed) return
                        completed = true
                        mainHandler.removeCallbacks(timeoutRunnable)

                        val elapsed = System.currentTimeMillis() - startTimeMs
                        Log.e(TAG, "╔══════════════════════════════════════════════════════════════╗")
                        Log.e(TAG, "║          Media3 Transformer 合并失败                        ║")
                        Log.e(TAG, "╠══════════════════════════════════════════════════════════════╣")
                        Log.e(TAG, "║ 已耗时     : ${formatDuration(elapsed)}")
                        Log.e(TAG, "║ errorCode  : ${exportException.errorCode}")
                        Log.e(TAG, "║ message    : ${exportException.message}")
                        Log.e(TAG, "║ cause      : ${exportException.cause}")
                        Log.e(TAG, "║ 视频文件   : $videoPath")
                        Log.e(TAG, "║   存在     : ${videoFile.exists()}")
                        Log.e(TAG, "║   大小     : ${formatFileSize(videoSize)}")
                        Log.e(TAG, "║   编码     : $videoCodecInfo")
                        Log.e(TAG, "║ 音频文件   : $audioPath")
                        Log.e(TAG, "║   存在     : ${audioFile.exists()}")
                        Log.e(TAG, "║   大小     : ${formatFileSize(audioSize)}")
                        Log.e(TAG, "║   编码     : $audioCodecInfo")
                        Log.e(TAG, "║ 输出路径   : $outputPath")
                        Log.e(TAG, "║   文件存在 : ${outFile.exists()}")
                        Log.e(TAG, "║   文件大小 : ${if (outFile.exists()) outFile.length() else "N/A"}")
                        Log.e(TAG, "║ exportResult.durationMs : ${exportResult.durationMs}")
                        Log.e(TAG, "╚══════════════════════════════════════════════════════════════╝")

                        val errorMsg = buildString {
                            append("Media3 Transformer 合并失败")
                            if (exportException.message != null) {
                                append(": ${exportException.message}")
                            }
                            append(" (errorCode=${exportException.errorCode})")
                        }
                        callback(false, null, errorMsg)
                    }
                })
                .build()

            transformer!!.start(composition, outputPath)
            Log.i(TAG, "Transformer 已启动，等待合并完成...")

        } catch (e: Exception) {
            if (completed) return
            completed = true
            mainHandler.removeCallbacks(timeoutRunnable)
            try { transformer?.cancel() } catch (_: Exception) {}

            val elapsed = System.currentTimeMillis() - startTimeMs
            Log.e(TAG, "╔══════════════════════════════════════════════════════════════╗")
            Log.e(TAG, "║       Media3 Transformer 初始化/启动失败                    ║")
            Log.e(TAG, "╠══════════════════════════════════════════════════════════════╣")
            Log.e(TAG, "║ 已耗时     : ${formatDuration(elapsed)}")
            Log.e(TAG, "║ 异常类型   : ${e.javaClass.simpleName}")
            Log.e(TAG, "║ 异常信息   : ${e.message}")
            Log.e(TAG, "║ 视频       : $videoPath")
            Log.e(TAG, "║   存在     : ${videoFile.exists()}")
            Log.e(TAG, "║   可读     : ${videoFile.canRead()}")
            Log.e(TAG, "║   大小     : ${formatFileSize(videoSize)}")
            Log.e(TAG, "║ 音频       : $audioPath")
            Log.e(TAG, "║   存在     : ${audioFile.exists()}")
            Log.e(TAG, "║   可读     : ${audioFile.canRead()}")
            Log.e(TAG, "║   大小     : ${formatFileSize(audioSize)}")
            Log.e(TAG, "║ 输出       : $outputPath")
            Log.e(TAG, "║   目录存在 : ${parentDir?.exists() ?: false}")
            Log.e(TAG, "║   可写     : ${parentDir?.canWrite() ?: false}")
            Log.e(TAG, "╚══════════════════════════════════════════════════════════════╝")
            Log.e(TAG, "完整堆栈:", e)
            callback(false, null, "Media3 Transformer 初始化失败: ${e.message}")
        }
    }

    // ──────────────────────────────────────────────────────────
    //  编码信息提取 & 无损检测
    // ──────────────────────────────────────────────────────────

    /**
     * 编码信息数据类：存储文件中所有轨道（track）的 MIME 类型列表。
     * 例如 [video/avc, audio/mp4a-latm] 表示 H.264 视频 + AAC 音频。
     */
    private data class CodecInfo(val tracks: List<String>) {
        override fun toString(): String {
            if (tracks.isEmpty()) return "(无法提取)"
            return tracks.joinToString(", ")
        }
    }

    /**
     * 使用 [MediaExtractor] 提取媒体文件中所有轨道的 MIME 类型。
     *
     * @param filePath 媒体文件路径
     * @return 包含所有轨道 MIME 类型的 [CodecInfo]；提取失败时返回空列表
     */
    private fun extractCodecInfo(filePath: String): CodecInfo {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(filePath)
            val tracks = mutableListOf<String>()
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: "unknown"
                // 简化常见的 MIME 显示
                val simplified = when {
                    mime == "video/avc" -> "H.264"
                    mime == "video/hevc" -> "H.265"
                    mime == "video/av01" -> "AV1"
                    mime == "video/x-vnd.on2.vp8" -> "VP8"
                    mime == "video/x-vnd.on2.vp9" -> "VP9"
                    mime == "audio/mp4a-latm" -> "AAC"
                    mime == "audio/mpeg" -> "MP3"
                    mime == "audio/opus" -> "Opus"
                    mime == "audio/vorbis" -> "Vorbis"
                    mime == "audio/flac" -> "FLAC"
                    else -> mime
                }
                tracks.add(simplified)
            }
            Log.d(TAG, "提取编码信息: $filePath -> $tracks")
            CodecInfo(tracks)
        } catch (e: Exception) {
            Log.w(TAG, "提取编码信息失败: $filePath - ${e.javaClass.simpleName}: ${e.message}")
            CodecInfo(emptyList())
        } finally {
            try { extractor.release() } catch (_: Exception) {}
        }
    }

    /**
     * 通过比对输入输出编码信息和文件大小比率，判断合并是否走了
     * passthrough（流复制 / 无损）模式。
     *
     * 判断依据：
     * 1. 输出轨道 MIME 类型与输入完全一致 → 编码器未被调用
     * 2. 输出文件大小与输入总和接近（85%~115%）→ 未发生压缩比变化
     *
     * @return true 表示很可能走了 passthrough（无损），false 表示可能走了转码（有损）
     */
    private fun detectPassthrough(
        videoInfo: CodecInfo,
        audioInfo: CodecInfo,
        outputInfo: CodecInfo,
        totalInputSize: Long,
        outputSize: Long
    ): Boolean {
        // 如果无法提取输出编码信息，仅通过文件大小比率粗略判断
        if (outputInfo.tracks.isEmpty()) {
            val ratio = if (totalInputSize > 0) outputSize.toDouble() / totalInputSize else 0.0
            val likelyPassthrough = ratio in 0.85..1.15
            Log.i(TAG, "无法提取输出编码信息，通过大小比率 (${String.format("%.1f", ratio * 100)}%) 粗略判断: ${if (likelyPassthrough) "可能是 passthrough" else "可能是转码"}")
            return likelyPassthrough
        }

        // 收集所有输入轨道 MIME 类型
        val inputMimes = (videoInfo.tracks + audioInfo.tracks).toSet()
        val outputMimes = outputInfo.tracks.toSet()

        // 编码 MIME 集合完全一致 → passthrough
        val codecsMatch = inputMimes.isNotEmpty() && inputMimes == outputMimes

        // 文件大小比率应在合理范围（passthrough 时容器开销略有差异）
        val ratio = if (totalInputSize > 0) outputSize.toDouble() / totalInputSize else 0.0
        val sizeReasonable = ratio in 0.80..1.20

        Log.i(TAG, "无损检测: 输入 tracks=$inputMimes, 输出 tracks=$outputMimes, codecsMatch=$codecsMatch, ratio=${String.format("%.1f", ratio * 100)}%, sizeReasonable=$sizeReasonable")

        return codecsMatch && sizeReasonable
    }

    // ──────────────────────────────────────────────────────────
    //  格式化工具方法
    // ──────────────────────────────────────────────────────────

    /**
     * 格式化文件大小为人类可读字符串。
     */
    private fun formatFileSize(bytes: Long): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "${"%.1f".format(bytes / 1024.0)} KB"
            bytes < 1024 * 1024 * 1024 -> "${"%.1f".format(bytes / (1024.0 * 1024))} MB"
            else -> "${"%.2f".format(bytes / (1024.0 * 1024 * 1024))} GB"
        }
    }

    /**
     * 格式化毫秒时长为人类可读字符串。
     */
    private fun formatDuration(ms: Long): String {
        val seconds = ms / 1000
        val minutes = seconds / 60
        val hours = minutes / 60
        return when {
            hours > 0 -> "${hours}h ${minutes % 60}m ${seconds % 60}s"
            minutes > 0 -> "${minutes}m ${seconds % 60}s"
            else -> "${seconds}.${(ms % 1000) / 100}s"
        }
    }
}
