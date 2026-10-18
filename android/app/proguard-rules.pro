# ProGuard / R8 规则

# path_provider_android 2.3+ 内部改用 JNI 实现（package:jni / jni_flutter），
# 这些 Java 类由 Dart 侧按类名查找，release 构建一旦被 R8 裁剪或改名，
# 取目录（启动阶段日志目录/下载目录）就会直接失败，应用会停在启动画面。
# 插件自带的 consumer 规则已覆盖，这里再显式保留一次作为双保险。
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# flutter_local_notifications 通过 GSON 反射反序列化通知模型，保留字段名以防万一。
-keep class com.dexterous.flutterlocalnotifications.** { *; }
