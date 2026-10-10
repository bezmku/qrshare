import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const kColorBg = Color(0xFF03313A);
const kColorBgLight = Color(0xFF054756);
const kColorAccent = Color(0xFF8FFE09);
const kColorAccentDim = Color(0xFF6DC900);
const kColorSurface = Color(0xFF042D38);
const kColorText = Color(0xFFE8F5F7);
const kColorTextMuted = Color(0xFF7FADB7);
const kColorError = Color(0xFFFF5C6A);
const kColorSuccess = Color(0xFF8FFE09);

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kColorBg,
    colorScheme: const ColorScheme.dark(
      primary: kColorAccent,
      onPrimary: kColorBg,
      secondary: kColorBgLight,
      onSecondary: kColorText,
      surface: kColorSurface,
      onSurface: kColorText,
      error: kColorError,
    ),
    fontFamily: 'RobotoMono',
    appBarTheme: const AppBarTheme(
      backgroundColor: kColorBg,
      foregroundColor: kColorText,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: kColorText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kColorAccent,
        foregroundColor: kColorBg,
        disabledBackgroundColor: kColorAccentDim.withValues(alpha: 0.4),
        disabledForegroundColor: kColorBg.withValues(alpha: 0.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kColorAccent,
        side: const BorderSide(color: kColorAccent, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      tileColor: kColorSurface,
      textColor: kColorText,
      iconColor: kColorAccent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kColorAccent,
      linearTrackColor: kColorBgLight,
    ),
    iconTheme: const IconThemeData(color: kColorAccent),
    dividerTheme: DividerThemeData(
      color: kColorBgLight.withValues(alpha: 0.6),
      thickness: 1,
    ),
  );
}
