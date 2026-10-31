import 'package:flutter/material.dart';

import 'core/theme/theme_controller.dart';
import 'features/home/home_page.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ThemeController.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final Brightness? brightnessOverride;

  const MyApp({
    super.key,
    this.fontFamily,
    this.fontFamilyFallback,
    this.brightnessOverride,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        final brightness =
            brightnessOverride ?? ThemeController.resolve(mode);
        return MaterialApp(
          title: '栖',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            brightness: brightness,
          ),
          home: const HomePage(),
        );
      },
    );
  }
}
