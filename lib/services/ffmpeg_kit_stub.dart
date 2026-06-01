/// Stub implementation for platforms where ffmpeg_kit_extended_flutter is not available.
/// Used only on web (dart.library.io absent). On native platforms the real
/// package is imported instead via ffmpeg_kit_real.dart.

class Session {
  dynamic getReturnCode() => null;
  String? getFailStackTrace() => null;
}

class ReturnCode {
  static bool isSuccess(dynamic returnCode) => false;
}

class FFmpegKit {
  static Future<Session> executeAsync(
    String command, {
    void Function(Session)? onComplete,
  }) async {
    final session = Session();
    onComplete?.call(session);
    return session;
  }
}

class FFmpegKitExtended {
  static Future<void> initialize() async {}
}
