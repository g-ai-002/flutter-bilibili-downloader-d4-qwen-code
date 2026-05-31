package com.bilibili.downloader

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.bilibili.downloader/ffmpeg"
        private const val TAG = "BilibiliDownloader"
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

                try {
                    mergeAvWithMediaMuxer(videoPath, audioPath, outputPath)
                    result.success(outputPath)
                    android.util.Log.i(TAG, "MediaMuxer 合并成功: $outputPath")
                } catch (e: Exception) {
                    android.util.Log.e(TAG, "MediaMuxer 合并失败", e)
                    result.error(
                        "MERGE_FAILED",
                        e.message ?: "MediaMuxer 合并未知错误",
                        e.toString()
                    )
                }
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * 使用 Android 原生 MediaExtractor + MediaMuxer 合并视频轨和音频轨。
     * 将 videoPath 的视频轨道与 audioPath 的音频轨道重新封装到 outputPath。
     *
     * 原理：MediaMuxer 仅做容器级封装（不解码/不重编码），速度接近文件拷贝，
     * 适用于 B 站 DASH 格式的 H.264/H.265 视频轨 + AAC 音频轨合并。
     */
    private fun mergeAvWithMediaMuxer(videoPath: String, audioPath: String, outputPath: String) {
        val videoFile = File(videoPath)
        val audioFile = File(audioPath)
        if (!videoFile.exists()) throw IllegalStateException("视频文件不存在: $videoPath")
        if (!audioFile.exists()) throw IllegalStateException("音频文件不存在: $audioPath")

        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()

        try {
            videoExtractor.setDataSource(videoPath)
            audioExtractor.setDataSource(audioPath)

            // 获取视频轨道索引
            var videoTrackIndex = -1
            var videoFormat: MediaFormat? = null
            for (i in 0 until videoExtractor.trackCount) {
                val fmt = videoExtractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/")) {
                    videoTrackIndex = i
                    videoFormat = fmt
                    break
                }
            }
            if (videoTrackIndex < 0) {
                throw IllegalStateException("源文件中未找到视频轨道: $videoPath")
            }

            // 获取音频轨道索引
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            for (i in 0 until audioExtractor.trackCount) {
                val fmt = audioExtractor.getTrackFormat(i)
                val mime = fmt.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = fmt
                    break
                }
            }
            if (audioTrackIndex < 0) {
                throw IllegalStateException("源文件中未找到音频轨道: $audioPath")
            }

            // 确保输出目录存在
            val outFile = File(outputPath)
            val parentDir = outFile.parentFile
            if (parentDir != null && !parentDir.exists()) {
                parentDir.mkdirs()
            }

            // 创建 MediaMuxer
            val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            try {
                val videoOutIndex = muxer.addTrack(videoFormat!!)
                val audioOutIndex = muxer.addTrack(audioFormat!!)

                muxer.start()

                // 写入视频轨道
                videoExtractor.selectTrack(videoTrackIndex)
                writeTrack(videoExtractor, muxer, videoOutIndex)

                // 写入音频轨道
                audioExtractor.selectTrack(audioTrackIndex)
                writeTrack(audioExtractor, muxer, audioOutIndex)
            } finally {
                try {
                    muxer.stop()
                } catch (_: Exception) {}
                try {
                    muxer.release()
                } catch (_: Exception) {}
            }
        } finally {
            videoExtractor.release()
            audioExtractor.release()
        }
    }

    /**
     * 将 extractor 中当前选中的轨道数据逐帧写入 muxer。
     * 每帧读取前调用 buffer.clear() 重置 buffer 位置，避免位置累积导致 MERGE_FAILED。
     */
    private fun writeTrack(extractor: MediaExtractor, muxer: MediaMuxer, trackIndex: Int) {
        val bufferInfo = android.media.MediaCodec.BufferInfo()
        val buffer = java.nio.ByteBuffer.allocate(256 * 1024)

        while (true) {
            buffer.clear() // 重置 buffer 位置，确保 readSampleData 从正确位置写入
            bufferInfo.offset = 0
            bufferInfo.size = extractor.readSampleData(buffer, 0)
            if (bufferInfo.size < 0) break

            bufferInfo.presentationTimeUs = extractor.sampleTime
            bufferInfo.flags = extractor.sampleFlags

            muxer.writeSampleData(trackIndex, buffer, bufferInfo)
            extractor.advance()
        }
    }
}
