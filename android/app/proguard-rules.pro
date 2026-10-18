# ProGuard / R8 规则
#
# 背景：Flutter 插件越来越多把实现改成 jnigen/JNI —— Dart 侧按「类名 + 方法签名」
# 反射查找 Kotlin/Java 成员（例如 shared_preferences_android 2.5.0 的
# SharedPreferencesApiRegistrar.getAll(String, List, Continuation)）。
# R8 看不到这类调用，release 包上运行时报：
#   java.lang.NoSuchMethodError: no non-static method "L...;.getAll(...)"
# 该问题在 debug / profile 下不出现（不跑 R8），只在 release 包暴露。
#
# 两个都得防：
#   1) 目标成员被裁剪/静态化 —— 用下面的 -keep 保留成员本身；
#   2) 签名里出现的类型被改名 —— 方法还在，但按原签名查不到，
#      同样报 NoSuchMethodError（见 kotlin.** 那条的实测记录）。
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

# Kotlin 标准库：JNI 查找按方法签名逐个类型名匹配，签名里出现的类型同样不能被改名。
# 实测 v0.4.29 的 release APK：kotlin.coroutines.Continuation 被改名成 d5
# （CoroutineContext -> i5），插件所有 suspend 方法的签名都成了 (..., Ld5;)Ljava/lang/Object;，
# 与 Dart 侧按 (..., Lkotlin/coroutines/Continuation;) 的查找对不上 ——
# 存储读写全部失败（设置/历史每次启动都像新装一样），报的仍是 NoSuchMethodError。
# kotlin.enums.EnumEntries、kotlin.jvm.internal.DefaultConstructorMarker 同样出现在
# 生成的签名里并被改名，所以整片保留，避免以后再逐个踩。
# 代价是标准库不再参与混淆/裁剪（dex 增大约 1～2 MB）；只在乎名字的话可换成
# -keepnames class kotlin.** { *; }
-keep class kotlin.** { *; }

# flutter_local_notifications 通过 GSON 反射反序列化通知模型，保留字段名。
-keep class com.dexterous.flutterlocalnotifications.** { *; }
