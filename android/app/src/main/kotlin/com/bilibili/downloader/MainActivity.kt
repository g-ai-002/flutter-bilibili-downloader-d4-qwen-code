package com.bilibili.downloader

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val PLAYER_CHANNEL = "com.bilibili.downloader/player"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAYER_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openVideo") {
                    val contentUri = call.argument<String>("uri") ?: ""
                    if (contentUri.isEmpty()) {
                        result.error("INVALID_URI", "content URI is empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(Uri.parse(contentUri), "video/*")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        // 先检查是否有可用播放器，避免 ActivityNotFoundException 崩溃
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("NO_PLAYER", "未找到可用的视频播放器", null)
                        }
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", "打开播放器失败: ${e.message}", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
