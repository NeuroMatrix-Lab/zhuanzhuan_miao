import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/converter_page.dart';
import 'pages/home_page.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const ZhuanzhuanMiaoApp());
}

class ZhuanzhuanMiaoApp extends StatelessWidget {
  const ZhuanzhuanMiaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '转转喵',
      debugShowCheckedModeBanner: false,
      theme: AppColors.light(),
      darkTheme: AppColors.dark(),
      themeMode: ThemeMode.system,
      onGenerateRoute: (settings) {
        if (settings.name == '/converter') {
          return MaterialPageRoute(
            builder: (_) => ConverterPage(
              files: (settings.arguments as List).cast(),
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const HomePage());
      },
    );
  }
}
