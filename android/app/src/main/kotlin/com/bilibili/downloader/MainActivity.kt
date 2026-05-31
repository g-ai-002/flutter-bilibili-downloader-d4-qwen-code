package com.bilibili.downloader

import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Transformer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CountDownLatch
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

                // 在后台线程执行合并，避免阻塞主线程
                Thread {
                    try {
                        mergeAvWithTransformer(videoPath, audioPath, outputPath)
                        runOnUiThread {
                            result.success(outputPath)
                            Log.i(TAG, "Media3 Transformer 合并成功: $outputPath")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Media3 Transformer 合并失败", e)
                        runOnUiThread {
                            result.error(
                                "MERGE_FAILED",
                                e.message ?: "Media3 Transformer 合并未知错误",
                                e.toString()
                            )
                        }
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * 使用 Jetpack Media3 Transformer 合并视频轨和音频轨。
     * 通过 Composition 将视频文件和音频文件的轨道合并输出。
     *
     * 原理：Transformer 优先使用 passthrough 模式（不解码/不重编码），
     * 仅在编解码格式不兼容时才回退到转码。
     */
    private fun mergeAvWithTransformer(videoPath: String, audioPath: String, outputPath: String) {
        val videoFile = File(videoPath)
        val audioFile = File(audioPath)
        if (!videoFile.exists()) throw IllegalStateException("视频文件不存在: $videoPath")
        if (!audioFile.exists()) throw IllegalStateException("音频文件不存在: $audioPath")

        // 确保输出目录存在
        val outFile = File(outputPath)
        val parentDir = outFile.parentFile
        if (parentDir != null && !parentDir.exists()) {
            parentDir.mkdirs()
        }

        val context = this
        val latch = CountDownLatch(1)
        var mergeError: Exception? = null
        var transformer: Transformer? = null

        try {
            val videoItem = MediaItem.fromUri(videoFile.toURI().toString())
            val audioItem = MediaItem.fromUri(audioFile.toURI().toString())

            // 创建包含视频的序列
            val videoSequence = EditedMediaItemSequence(
                EditedMediaItem.Builder(videoItem).build()
            )

            // 创建包含音频的序列
            val audioSequence = EditedMediaItemSequence(
                EditedMediaItem.Builder(audioItem).build()
            )

            // 组合两个序列，Transformer 会自动对齐时间戳
            val composition = Composition.Builder(listOf(videoSequence, audioSequence))
                .build()

            transformer = Transformer.Builder(context)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(
                        composition: Composition,
                        exportResult: Transformer.ExportResult
                    ) {
                        Log.i(
                            TAG, "Transformer 合并完成: output=$outputPath, " +
                                "durationMs=${exportResult.durationMs}, " +
                                "fileSizeBytes=${exportResult.fileSizeBytes}"
                        )
                        latch.countDown()
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: Transformer.ExportResult,
                        exportException: Transformer.ExportException
                    ) {
                        Log.e(
                            TAG,
                            "Transformer 合并失败: errorCode=${exportException.errorCode}",
                            exportException
                        )
                        mergeError = RuntimeException(
                            "Media3 Transformer 合并失败: ${exportException.message} " +
                                "(errorCode=${exportException.errorCode})",
                            exportException
                        )
                        latch.countDown()
                    }
                })
                .build()

            transformer!!.start(composition, outputPath)

            // 等待合并完成（最多 120 秒）
            if (!latch.await(MERGE_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                transformer!!.cancel()
                throw RuntimeException("Media3 Transformer 合并超时 (${MERGE_TIMEOUT_SECONDS}s)")
            }

            // 检查是否在监听器中记录了错误
            if (mergeError != null) {
                throw mergeError!!
            }

            // 验证输出文件
            if (!outFile.exists() || outFile.length() == 0L) {
                throw RuntimeException("Media3 Transformer 合并输出文件不存在或为空: $outputPath")
            }
        } finally {
            try {
                transformer?.release()
            } catch (_: Exception) {}
        }
    }
}
