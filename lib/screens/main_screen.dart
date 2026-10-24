import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'browse_screen.dart';
import 'dashboard_screen.dart';
import 'lyrics_screen.dart';
import 'prayer_screen.dart';
import 'sports_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    LyricsScreen(),
    PrayerScreen(),
    SportsScreen(),
    BrowseScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.accentTeal.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentTeal);
            }
            return const TextStyle(fontSize: 11, color: AppColors.textDim);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.accentTeal, size: 22);
            }
            return const IconThemeData(color: AppColors.textDim, size: 22);
          }),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car),
              label: 'Car',
            ),
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined),
              selectedIcon: Icon(Icons.music_note),
              label: 'Lyrics',
            ),
            NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque),
              label: 'Prayer',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_soccer_outlined),
              selectedIcon: Icon(Icons.sports_soccer),
              label: 'Football',
            ),
            NavigationDestination(
              icon: Icon(Icons.public_outlined),
              selectedIcon: Icon(Icons.public),
              label: 'Browse',
            ),
          ],
        ),
      ),
    );
  }
}
