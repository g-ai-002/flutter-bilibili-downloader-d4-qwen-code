package com.bilibili.downloader

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
        private const val MERGE_TIMEOUT_SECONDS = 120L
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

                // 在主线程上使用 Media3 Transformer（Media3 要求在创建线程上执行所有操作）
                mergeAvWithTransformer(videoPath, audioPath, outputPath) { success, mergedPath, errorMsg ->
                    if (success && mergedPath != null) {
                        result.success(mergedPath)
                        Log.i(TAG, "Media3 Transformer 合并成功: $mergedPath")
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
     * 优先使用 passthrough 模式（不解码/不重编码），格式不兼容时才回退到转码。
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
        val videoFile = File(videoPath)
        val audioFile = File(audioPath)
        if (!videoFile.exists()) {
            callback(false, null, "视频文件不存在: $videoPath")
            return
        }
        if (!audioFile.exists()) {
            callback(false, null, "音频文件不存在: $audioPath")
            return
        }

        // 确保输出目录存在
        val outFile = File(outputPath)
        val parentDir = outFile.parentFile
        if (parentDir != null && !parentDir.exists()) {
            parentDir.mkdirs()
        }

        val context = this
        var transformer: Transformer? = null
        var completed = false

        // 使用 Handler 设置超时
        val timeoutRunnable = Runnable {
            if (!completed) {
                completed = true
                try { transformer?.cancel() } catch (_: Exception) {}
                Log.e(TAG, "Media3 Transformer 合并超时 (${MERGE_TIMEOUT_SECONDS}s)")
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

            transformer = Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(
                        composition: Composition,
                        exportResult: ExportResult
                    ) {
                        if (completed) return
                        completed = true
                        mainHandler.removeCallbacks(timeoutRunnable)

                        Log.i(
                            TAG, "Transformer 合并完成: output=$outputPath, " +
                                "durationMs=${exportResult.durationMs}, " +
                                "fileSizeBytes=${exportResult.fileSizeBytes}"
                        )

                        // 验证输出文件
                        if (!outFile.exists() || outFile.length() == 0L) {
                            callback(false, null, "合并输出文件不存在或为空: $outputPath")
                            return
                        }

                        // 合并成功，删除中间文件
                        try {
                            videoFile.delete()
                            audioFile.delete()
                        } catch (_: Exception) {}

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

                        Log.e(
                            TAG,
                            "Transformer 合并失败: errorCode=${exportException.errorCode}",
                            exportException
                        )
                        callback(
                            false,
                            null,
                            "Media3 Transformer 合并失败: ${exportException.message} " +
                                "(errorCode=${exportException.errorCode})"
                        )
                    }
                })
                .build()

            transformer!!.start(composition, outputPath)

        } catch (e: Exception) {
            if (completed) return
            completed = true
            mainHandler.removeCallbacks(timeoutRunnable)
            try { transformer?.cancel() } catch (_: Exception) {}

            Log.e(TAG, "Media3 Transformer 初始化失败", e)
            callback(false, null, "Media3 Transformer 初始化失败: ${e.message}")
        }
    }
}
