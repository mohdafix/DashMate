import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DashMateApp());
}

class DashMateApp extends StatelessWidget {
  const DashMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DashMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // System bars follow the active theme (dark icons by day, light by night).
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        final t = context.tokens;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: t.bg,
            systemNavigationBarIconBrightness:
                dark ? Brightness.light : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const DashboardScreen(),
    );
  }
}
