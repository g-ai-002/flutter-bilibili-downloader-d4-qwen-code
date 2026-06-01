/// Platform-conditional export: uses the real ffmpeg_kit on native platforms
/// and a stub on web, so that the app compiles everywhere even though
/// ffmpeg_kit_extended_flutter is restricted to android in pubspec.yaml.
export 'ffmpeg_kit_stub.dart'
    if (dart.library.io) 'ffmpeg_kit_real.dart';
