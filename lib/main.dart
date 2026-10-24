import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style to dark transparent status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const DashMateApp());
}

class DashMateApp extends StatelessWidget {
  const DashMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DashMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accentTeal,
          brightness: Brightness.dark,
          surface: AppColors.surface,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const DashboardScreen(),
    );
  }
}
