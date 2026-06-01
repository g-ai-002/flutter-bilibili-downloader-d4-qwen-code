package com.bilibili.downloader

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.bilibili.downloader/merge"
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
                    result.error("INVALID_ARGS", "缺少视频/音频/输出路径参数", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        mergeAv(videoPath, audioPath, outputPath)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MERGE_FAILED", e.message ?: "合并失败", null)
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * 使用 Android 原生 MediaExtractor + MediaMuxer 无损合并视频轨与音频轨。
     * Bilibili DASH 格式中，视频文件和音频文件各自仅含单一轨道，
     * 因此直接提取视频轨与音频轨并重新封装即可，无需转码。
     */
    private fun mergeAv(videoPath: String, audioPath: String, outputPath: String) {
        val videoExtractor = MediaExtractor()
        val audioExtractor = MediaExtractor()
        var muxer: MediaMuxer? = null

        try {
            videoExtractor.setDataSource(videoPath)
            audioExtractor.setDataSource(audioPath)

            // 查找视频轨
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
            if (videoTrackIndex == -1) {
                throw Exception("视频文件中未找到视频轨道")
            }

            // 查找音频轨
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
            if (audioTrackIndex == -1) {
                throw Exception("音频文件中未找到音频轨道")
            }

            // 创建 MediaMuxer（MP4 输出）
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            // 选择轨道并添加至 muxer
            videoExtractor.selectTrack(videoTrackIndex)
            val videoMuxerIdx = muxer.addTrack(videoFormat!!)

            audioExtractor.selectTrack(audioTrackIndex)
            val audioMuxerIdx = muxer.addTrack(audioFormat!!)

            muxer.start()

            val buffer = ByteBuffer.allocate(256 * 1024) // 256KB
            val bufferInfo = MediaCodec.BufferInfo()

            // 写入视频轨
            while (true) {
                buffer.clear()
                val sampleSize = videoExtractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = videoExtractor.sampleTime
                bufferInfo.flags = videoExtractor.sampleFlags
                muxer.writeSampleData(videoMuxerIdx, buffer, bufferInfo)
                videoExtractor.advance()
            }

            // 写入音频轨
            while (true) {
                buffer.clear()
                val sampleSize = audioExtractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                bufferInfo.offset = 0
                bufferInfo.size = sampleSize
                bufferInfo.presentationTimeUs = audioExtractor.sampleTime
                bufferInfo.flags = audioExtractor.sampleFlags
                muxer.writeSampleData(audioMuxerIdx, buffer, bufferInfo)
                audioExtractor.advance()
            }

            muxer.stop()
        } finally {
            videoExtractor.release()
            audioExtractor.release()
            muxer?.release()
        }
    }
}
