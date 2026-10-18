# ProGuard / R8 规则
#
# 背景：Flutter 插件越来越多把实现改成 jnigen/JNI —— Dart 侧按「类名 + 方法签名」
# 反射查找 Kotlin/Java 成员（例如 shared_preferences_android 2.5.0 的
# SharedPreferencesApiRegistrar.getAll(String, List, Continuation)）。
# R8 看不到这类调用，会把成员裁剪或静态化，release 包上运行时报：
#   java.lang.NoSuchMethodError: no non-static method "L...;.getAll(...)"
# 该问题在 debug / profile 下不出现，只在 release 包暴露。
#
# 这些规则不加 allowoptimization / allowshrinking，因此保留成员的同时也禁止
# R8 改动其形态（静态化、内联），保证 JNI 反射查找仍能命中。

# Flutter 插件整体保留：插件自带的 consumer 规则不覆盖 JNI 场景，
# 这里显式保留（也包含 io.flutter.plugins.GeneratedPluginRegistrant）。
-keep class io.flutter.plugins.** { *; }

# package:jni / jni_flutter：Dart 侧经 JNI 调用的辅助类，
# path_provider 2.3+ 与 shared_preferences_android 2.5+ 都依赖它。
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }

# flutter_local_notifications 通过 GSON 反射反序列化通知模型，保留字段名。
-keep class com.dexterous.flutterlocalnotifications.** { *; }
