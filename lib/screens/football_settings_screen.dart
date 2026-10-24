import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/secrets.dart';
import '../theme/app_colors.dart';

class FootballSettingsScreen extends StatefulWidget {
  const FootballSettingsScreen({super.key});

  @override
  State<FootballSettingsScreen> createState() => _FootballSettingsScreenState();
}

class _FootballSettingsScreenState extends State<FootballSettingsScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  final TextEditingController _apiKeyController = TextEditingController();

  final List<Map<String, String>> _competitions = const [
    {'code': 'PL', 'name': 'Premier League', 'country': 'England'},
    {'code': 'CL', 'name': 'UEFA Champions League', 'country': 'Europe'},
    {'code': 'PD', 'name': 'La Liga', 'country': 'Spain'},
    {'code': 'SA', 'name': 'Serie A', 'country': 'Italy'},
    {'code': 'BL1', 'name': 'Bundesliga', 'country': 'Germany'},
    {'code': 'FL1', 'name': 'Ligue 1', 'country': 'France'},
  ];

  final Set<String> _selectedCompetitions = {'PL', 'CL'};

  final List<String> _popularTeams = const [
    'Arsenal',
    'Liverpool',
    'Manchester City',
    'Manchester United',
    'Chelsea',
    'Tottenham Hotspur',
    'Real Madrid',
    'Barcelona',
    'Atletico Madrid',
    'Bayern Munich',
    'Borussia Dortmund',
    'Paris Saint-Germain',
    'Juventus',
    'Inter Milan',
    'AC Milan',
  ];

  final Set<String> _favouriteTeams = {'Arsenal', 'Liverpool'};

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = AppSecrets.footballDataApiKey;
    _loadPrefs();
  }

  void _loadPrefs() async {
    try {
      final res = await _channel.invokeMethod('getFootballPrefs');
      if (res != null && res is Map && mounted) {
        setState(() {
          final comps = res['competitions'] as List<dynamic>?;
          if (comps != null && comps.isNotEmpty) {
            _selectedCompetitions.clear();
            _selectedCompetitions.addAll(comps.map((e) => e.toString()));
          }
          final teams = res['favouriteTeams'] as List<dynamic>?;
          if (teams != null && teams.isNotEmpty) {
            _favouriteTeams.clear();
            _favouriteTeams.addAll(teams.map((e) => e.toString()));
          }
          final key = res['apiKey'] as String?;
          if (key != null && key.isNotEmpty) {
            _apiKeyController.text = key;
            AppSecrets.footballDataApiKey = key;
          }
        });
      }
    } catch (_) {}
  }

  void _savePrefs() {
    AppSecrets.footballDataApiKey = _apiKeyController.text.trim();
    _channel.invokeMethod('setFootballPrefs', {
      'apiKey': _apiKeyController.text.trim(),
      'competitions': _selectedCompetitions.toList(),
      'favouriteTeams': _favouriteTeams.toList(),
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Football settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Subtitle
          const Text(
            'What the Football page follows. Pick your favourite leagues and clubs for live scores and car card alerts.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // 1. API Key Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key, color: AppColors.accentTeal, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'football-data.org API key',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppSecrets.hasFootballKey
                            ? const Color(0xFF065F46)
                            : Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppSecrets.hasFootballKey ? 'Active' : 'Optional',
                        style: TextStyle(
                          color: AppSecrets.hasFootballKey
                              ? const Color(0xFF34D399)
                              : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your free token from football-data.org to enable live match scores on phone and car card.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSub, height: 1.35),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _apiKeyController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Paste API token here',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F1420),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentTeal),
                    ),
                  ),
                  onChanged: (_) => _savePrefs(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Competitions to Follow
          const Text(
            'Competitions to follow',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: _competitions.asMap().entries.map((entry) {
                final idx = entry.key;
                final comp = entry.value;
                final isSelected = _selectedCompetitions.contains(comp['code']);
                final isLast = idx == _competitions.length - 1;

                return Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? AppColors.accentTeal.withValues(alpha: 0.15)
                            : Colors.white10,
                        child: Text(
                          comp['code']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.accentTeal : Colors.white70,
                          ),
                        ),
                      ),
                      title: Text(
                        comp['name']!,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      subtitle: Text(
                        comp['country']!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSub),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: AppColors.accentTeal,
                        checkColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedCompetitions.add(comp['code']!);
                            } else {
                              if (_selectedCompetitions.length > 1) {
                                _selectedCompetitions.remove(comp['code']!);
                              }
                            }
                          });
                          _savePrefs();
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            if (_selectedCompetitions.length > 1) {
                              _selectedCompetitions.remove(comp['code']!);
                            }
                          } else {
                            _selectedCompetitions.add(comp['code']!);
                          }
                        });
                        _savePrefs();
                      },
                    ),
                    if (!isLast) const Divider(height: 1, indent: 56, endIndent: 16, color: Colors.white10),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),

          // 3. My Teams / Favourite Clubs
          const Text(
            'My teams (Pasukan saya)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'When your teams play, their live score automatically appears on the Android Auto car card.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSub),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _popularTeams.map((team) {
              final isFav = _favouriteTeams.contains(team);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isFav) {
                      _favouriteTeams.remove(team);
                    } else {
                      _favouriteTeams.add(team);
                    }
                  });
                  _savePrefs();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFav ? const Color(0xFF0F766E) : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFav ? AppColors.accentTeal : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFav ? Icons.star : Icons.star_border,
                        size: 16,
                        color: isFav ? const Color(0xFFFFD54F) : Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        team,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isFav ? FontWeight.bold : FontWeight.normal,
                          color: isFav ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 36),
        ],
      ),
    );
  }
}
