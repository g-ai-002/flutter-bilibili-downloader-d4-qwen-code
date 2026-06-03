import 'package:flutter/material.dart';

/// 国内审美主题 — 克制、扁平、灰底白卡、0.5px 极细线条
///
/// 核心口诀：去阴影、灰底白卡、0.5像素线、标题居中、干掉水波纹

// ── 品牌色（黑） ──
const _primaryColor = Color(0xFF333333);

// ── 浅色主题色板 ──
const _lightSurface = Color(0xFFFFFFFF);
const _lightBackground = Color(0xFFFAFBFC);
const _lightSurfaceVariant = Color(0xFFF0F1F3);
const _lightOnSurface = Color(0xFF333333);
const _lightOnSurfaceVariant = Color(0xFF666666);
const _lightOutline = Color(0xFFEEEEEE);
const _lightPrimaryContainer = Color(0xFFE0E0E0);

// ── 深色主题色板 ──
const _darkSurface = Color(0xFF252525);
const _darkBackground = Color(0xFF1A1A1A);
const _darkSurfaceVariant = Color(0xFF333333);
const _darkOnSurface = Color(0xFFE0E0E0);
const _darkOnSurfaceVariant = Color(0xFFAAAAAA);
const _darkOutline = Color(0xFF3A3A3A);
const _darkPrimaryContainer = Color(0xFF7B1F3D);

/// 浅色国内审美主题
ThemeData chinaLightTheme({String? fontFamily}) {
  final colorScheme = const ColorScheme.light(
    primary: _primaryColor,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE0E0E0),
    onPrimaryContainer: const Color(0xFF1A1A1A),
    secondary: Color(0xFF5C6BC0),
    onSecondary: Colors.white,
    surface: _lightSurface,
    onSurface: _lightOnSurface,
    surfaceVariant: _lightSurfaceVariant,
    onSurfaceVariant: _lightOnSurfaceVariant,
    error: Color(0xFFE53935),
    onError: Colors.white,
    outline: _lightOutline,
    tertiary: Color(0xFFF5A623),
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    primaryColor: _primaryColor,
    scaffoldBackgroundColor: _lightBackground,
    colorScheme: colorScheme,

    // 字体：偏好苹方/微软雅黑
    textTheme: _buildTextTheme(
      onSurface: _lightOnSurface,
      onSurfaceVariant: _lightOnSurfaceVariant,
      fontFamily: fontFamily,
    ),

    // AppBar：去阴影、标题居中、无 M3 蒙版、0.5px 底部分隔线、紧凑高度
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightSurface,
      foregroundColor: _lightOnSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 44,
      shape: Border(
        bottom: BorderSide(color: _lightOutline, width: 0.5),
      ),
    ),

    // 底部导航栏：紧凑高度、0.5px 顶部分隔线（由各页面 Container 提供）
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _lightSurface,
      selectedItemColor: _primaryColor,
      unselectedItemColor: _lightOnSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11),
      unselectedLabelStyle: TextStyle(fontSize: 11),
      selectedIconTheme: IconThemeData(size: 20),
      unselectedIconTheme: IconThemeData(size: 20),
    ),

    // 侧边导航栏：紧凑尺寸
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      selectedIconTheme: const IconThemeData(color: _primaryColor, size: 20),
      unselectedIconTheme:
          const IconThemeData(color: _lightOnSurfaceVariant, size: 20),
      selectedLabelTextStyle: const TextStyle(
        color: _primaryColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: _lightOnSurfaceVariant,
        fontSize: 11,
      ),
      indicatorColor: _primaryColor.withOpacity(0.08),
    ),

    // 分割线：0.5px 极细线
    dividerTheme: const DividerThemeData(
      color: _lightOutline,
      thickness: 0.5,
      space: 0.5,
    ),

    // 列表项
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF555555),
      textColor: _lightOnSurface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),

    // 卡片：去阴影、白色背景
    cardTheme: const CardThemeData(
      elevation: 0,
      color: _lightSurface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
    ),

    // 按钮：去阴影、小圆角
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),

    // 输入框：小圆角、细边框
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightOutline, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _lightOutline, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryColor, width: 1),
      ),
    ),

    // 去除水波纹
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,

    // 底部弹窗/提示
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// 深色国内审美主题
ThemeData chinaDarkTheme({String? fontFamily}) {
  final colorScheme = const ColorScheme.dark(
    primary: const Color(0xFFCCCCCC),
    onPrimary: const Color(0xFF1A1A1A),
    primaryContainer: _darkPrimaryContainer,
    onPrimaryContainer: const Color(0xFFE0E0E0),
    secondary: Color(0xFF7986CB),
    onSecondary: Color(0xFF1A1A1A),
    surface: _darkSurface,
    onSurface: _darkOnSurface,
    surfaceVariant: _darkSurfaceVariant,
    onSurfaceVariant: _darkOnSurfaceVariant,
    error: Color(0xFFEF5350),
    onError: Color(0xFF1A1A1A),
    outline: _darkOutline,
    tertiary: Color(0xFFFFB74D),
    surfaceTint: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    primaryColor: const Color(0xFFCCCCCC),
    scaffoldBackgroundColor: _darkBackground,
    colorScheme: colorScheme,

    textTheme: _buildTextTheme(
      onSurface: _darkOnSurface,
      onSurfaceVariant: _darkOnSurfaceVariant,
      fontFamily: fontFamily,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: _darkSurface,
      foregroundColor: _darkOnSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 44,
      shape: Border(
        bottom: BorderSide(color: _darkOutline, width: 0.5),
      ),
    ),

    // 底部导航栏：紧凑高度、0.5px 顶部分隔线（由各页面 Container 提供）
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: _darkSurface,
      selectedItemColor: Color(0xFFCCCCCC),
      unselectedItemColor: _darkOnSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 11),
      unselectedLabelStyle: TextStyle(fontSize: 11),
      selectedIconTheme: IconThemeData(size: 20),
      unselectedIconTheme: IconThemeData(size: 20),
    ),

    // 侧边导航栏：紧凑尺寸
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      selectedIconTheme:
          const IconThemeData(color: Color(0xFFCCCCCC), size: 20),
      unselectedIconTheme:
          const IconThemeData(color: _darkOnSurfaceVariant, size: 20),
      selectedLabelTextStyle: const TextStyle(
        color: Color(0xFFCCCCCC),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: _darkOnSurfaceVariant,
        fontSize: 11,
      ),
      indicatorColor: const Color(0xFF7B1F3D),
    ),

    dividerTheme: const DividerThemeData(
      color: _darkOutline,
      thickness: 0.5,
      space: 0.5,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: _darkOnSurfaceVariant,
      textColor: _darkOnSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),

    cardTheme: const CardThemeData(
      elevation: 0,
      color: _darkSurface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: const Color(0xFFCCCCCC),
        foregroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkOutline, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _darkOutline, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1),
      ),
    ),

    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

TextTheme _buildTextTheme({
  required Color onSurface,
  required Color onSurfaceVariant,
  String? fontFamily,
}) {
  return TextTheme(
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: onSurface,
      fontFamily: fontFamily,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: onSurface,
      fontFamily: fontFamily,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: onSurface,
      fontFamily: fontFamily,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: onSurface,
      fontFamily: fontFamily,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: onSurface,
      fontFamily: fontFamily,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      color: onSurfaceVariant,
      fontFamily: fontFamily,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: onSurface,
      fontFamily: fontFamily,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      color: onSurfaceVariant,
      fontFamily: fontFamily,
    ),
  );
}
