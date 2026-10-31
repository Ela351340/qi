import 'package:flutter/material.dart';

/// 一套完整配色。所有界面颜色都从这里取，切换主题只换这个对象。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentSoft;
  final Color danger;
  final Color dangerSoft;
  final Color bubbleSelf;
  final Color bubbleOther;

  const AppColors({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.bubbleSelf,
    required this.bubbleOther,
  });

  /// 深色：不用纯黑，靠三级表面拉层次，用极淡描边代替阴影。
  static const dark = AppColors(
    bg: Color(0xFF000000),
    surface1: Color(0xFF000000),
    surface2: Color(0xFF000000),
    surface3: Color(0xFF000000),
    border: Color(0xFF2A2A33),
    borderStrong: Color(0xFF34343F),
    textPrimary: Color(0xFFECECF0),
    textSecondary: Color(0xFF8E8E99),
    textTertiary: Color(0xFF63636E),
    accent: Color(0xFF7A6BFF),
    accentSoft: Color(0xFF2B2555),
    danger: Color(0xFFFF5C5C),
    dangerSoft: Color(0xFF331C1F),
    bubbleSelf: Color(0xFF2B2555),
    bubbleOther: Color(0xFF1F1F25),
  );

  /// 浅色（默认）：白底但不用纯白，避免和气泡糊在一起。
  static const light = AppColors(
    bg: Color(0xFFF4F4F7),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFFFFFFF),
    surface3: Color(0xFFFBFBFD),
    border: Color(0xFFE7E7EC),
    borderStrong: Color(0xFFD6D6DE),
    textPrimary: Color(0xFF16161C),
    textSecondary: Color(0xFF6B6B77),
    textTertiary: Color(0xFF9A9AA6),
    accent: Color(0xFF5A4BE0),
    accentSoft: Color(0xFFEDEBFF),
    danger: Color(0xFFD92D20),
    dangerSoft: Color(0xFFFFEDEC),
    bubbleSelf: Color(0xFF5A4BE0),
    bubbleOther: Color(0xFFFFFFFF),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? dark;

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentSoft,
    Color? danger,
    Color? dangerSoft,
    Color? bubbleSelf,
    Color? bubbleOther,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      bubbleSelf: bubbleSelf ?? this.bubbleSelf,
      bubbleOther: bubbleOther ?? this.bubbleOther,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      bubbleSelf: Color.lerp(bubbleSelf, other.bubbleSelf, t)!,
      bubbleOther: Color.lerp(bubbleOther, other.bubbleOther, t)!,
    );
  }
}

/// 当前生效的配色。
///
/// 这是个便利访问器：界面代码里大量用到颜色，很多地方拿不到 BuildContext
/// （比如 State 的辅助方法、静态工具），统一从这里取。
/// 真值是 ThemeExtension；[applyThemeColors] 在构建 ThemeData 时同步过来，
/// 主题切换会整棵树重建，所以不会读到过期的值。
AppColors _current = AppColors.light;

/// 全局配色简写，界面里直接用 `C.accent` 这样取。
AppColors get C => _current;

void applyThemeColors(AppColors colors) => _current = colors;

/// 尺寸常量（与主题无关）
class AppMetrics {  static const double topBarHeight = 56;
  static const double avatarSize = 38;
  static const double avatarRadius = 12;
  static const double bubbleRadius = 16;
  static const double bubbleTightRadius = 5;
  static const double bubbleMaxRatio = 0.72;
  static const double gap = 8;
  static const double messageGap = 10;
  static const double inputBarHeight = 64;
  static const double inputFieldHeight = 44;
  static const double panelRatio = 0.23;
  static const double cardRadius = 16;
}

/// 文字样式只给字号/字重/行高，**不带颜色**。
/// 颜色交给 ThemeData（自动跟随明暗）和各处显式指定。
class AppText {
  static const TextStyle title =
      TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static const TextStyle subtitle = TextStyle(fontSize: 11, height: 1.2);
  static const TextStyle body = TextStyle(fontSize: 16, height: 1.45);
  static const TextStyle bodySmall = TextStyle(fontSize: 15, height: 1.4);
  static const TextStyle meta = TextStyle(fontSize: 12);
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );
}

ThemeData buildAppTheme({
  String? fontFamily,
  List<String>? fontFamilyFallback,
  Brightness brightness = Brightness.light,
}) {
  final colors =
      brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  applyThemeColors(colors);
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    scaffoldBackgroundColor: colors.bg,
  );
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
    ).copyWith(surface: colors.bg),
    extensions: [colors],
    textTheme: base.textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accent.withValues(alpha: 0.3),
      selectionHandleColor: colors.accent,
    ),
  );
}
