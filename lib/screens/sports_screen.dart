import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/secrets.dart';
import '../theme/app_colors.dart';

class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  int _selectedTabIndex = 0; // 0: Games, 1: My Teams, 2: Tables
  String _selectedLeague = 'All';

  final List<String> _leagues = [
    'All',
    'Premier League',
    'Champions League',
    'La Liga',
    'Malaysia Super League',
    'Serie A',
    'Bundesliga',
    'AFC Champions League',
  ];

  final Set<String> _favouriteTeams = {'Arsenal', 'Liverpool', 'JDT'};

  final List<Map<String, dynamic>> _matches = [
    {
      'id': 'm1',
      'league': 'Premier League',
      'home': 'Arsenal',
      'away': 'Liverpool',
      'homeScore': 2,
      'awayScore': 1,
      'status': 'live',
      'minute': "74'",
      'time': '20:30',
      'venue': 'Emirates Stadium',
    },
    {
      'id': 'm2',
      'league': 'Premier League',
      'home': 'Man City',
      'away': 'Chelsea',
      'homeScore': 0,
      'awayScore': 0,
      'status': 'upcoming',
      'minute': '',
      'time': '23:00',
      'venue': 'Etihad Stadium',
    },
    {
      'id': 'm3',
      'league': 'Champions League',
      'home': 'Real Madrid',
      'away': 'Bayern Munich',
      'homeScore': 3,
      'awayScore': 2,
      'status': 'ft',
      'minute': 'FT',
      'time': 'Yesterday',
      'venue': 'Santiago Bernabéu',
    },
    {
      'id': 'm4',
      'league': 'Malaysia Super League',
      'home': 'JDT',
      'away': 'Selangor FC',
      'homeScore': 3,
      'awayScore': 0,
      'status': 'live',
      'minute': "62'",
      'time': '21:00',
      'venue': 'Sultan Ibrahim Stadium',
    },
    {
      'id': 'm5',
      'league': 'La Liga',
      'home': 'Barcelona',
      'away': 'Atletico Madrid',
      'homeScore': 1,
      'awayScore': 1,
      'status': 'live',
      'minute': "81'",
      'time': '22:15',
      'venue': 'Camp Nou',
    },
    {
      'id': 'm6',
      'league': 'AFC Champions League',
      'home': 'Al-Hilal',
      'away': 'Ulsan HD',
      'homeScore': 2,
      'awayScore': 0,
      'status': 'ft',
      'minute': 'FT',
      'time': 'Yesterday',
      'venue': 'Kingdom Arena',
    },
  ];

  final List<Map<String, dynamic>> _standings = [
    {'pos': 1, 'team': 'Arsenal', 'p': 28, 'w': 20, 'd': 4, 'l': 4, 'gd': '+38', 'pts': 64},
    {'pos': 2, 'team': 'Liverpool', 'p': 28, 'w': 19, 'd': 6, 'l': 3, 'gd': '+35', 'pts': 63},
    {'pos': 3, 'team': 'Man City', 'p': 28, 'w': 19, 'd': 5, 'l': 4, 'gd': '+32', 'pts': 62},
    {'pos': 4, 'team': 'Aston Villa', 'p': 28, 'w': 17, 'd': 4, 'l': 7, 'gd': '+18', 'pts': 55},
    {'pos': 5, 'team': 'Tottenham', 'p': 28, 'w': 16, 'd': 5, 'l': 7, 'gd': '+16', 'pts': 53},
    {'pos': 6, 'team': 'Man United', 'p': 28, 'w': 15, 'd': 2, 'l': 11, 'gd': '0', 'pts': 47},
    {'pos': 7, 'team': 'Chelsea', 'p': 28, 'w': 12, 'd': 7, 'l': 9, 'gd': '+7', 'pts': 43},
  ];

  Timer? _liveTicker;

  @override
  void initState() {
    super.initState();
    _liveTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    super.dispose();
  }

  void _pushSportsToCar() {
    HapticFeedback.lightImpact();
    _channel.invokeMethod('setCarPage', {'page': 'sports'});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Displaying Sports scores on Android Auto screen', style: TextStyle(color: AppColors.tealAccent)),
        backgroundColor: AppColors.cardBg,
      ),
    );
  }

  void _toggleFavourite(String team) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_favouriteTeams.contains(team)) {
        _favouriteTeams.remove(team);
      } else {
        _favouriteTeams.add(team);
      }
    });
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: AppSecrets.footballDataApiKey);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16253B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('football-data.org Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add your football-data.org key to AutoDeck (or in lib/core/secrets.dart) to fetch live scores, fixtures and league tables.\n\nTambah kunci football-data.org di lib/core/secrets.dart.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter API Token / Masukkan Kunci...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.white60)),
            ),
            TextButton(
              onPressed: () {
                AppSecrets.footballDataApiKey = controller.text.trim();
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('football-data.org key updated')),
                );
              },
              child: const Text('Simpan', style: TextStyle(color: AppColors.tealAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMatches = _selectedLeague == 'All'
        ? _matches
        : _matches.where((m) => m['league'] == _selectedLeague).toList();

    final myMatches = _matches.where((m) =>
        _favouriteTeams.contains(m['home']) || _favouriteTeams.contains(m['away'])).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Sports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'API Key',
            icon: const Icon(Icons.key, color: AppColors.accentTeal),
            onPressed: _showApiKeyDialog,
          ),
          IconButton(
            tooltip: 'Display on Car Screen',
            icon: const Icon(Icons.directions_car_outlined, color: AppColors.accentTeal),
            onPressed: _pushSportsToCar,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 3 Segmented Tabs: [ Games ] [ My Teams ] [ Tables ]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Games', Icons.sports_soccer),
                    _buildTabButton(1, 'My Teams', Icons.star_outline),
                    _buildTabButton(2, 'Tables', Icons.table_chart_outlined),
                  ],
                ),
              ),
            ),

            // League Selector Chips (When Games tab is active)
            if (_selectedTabIndex == 0)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _leagues.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final l = _leagues[idx];
                    final isSel = l == _selectedLeague;
                    return ChoiceChip(
                      label: Text(l, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.black : Colors.white70)),
                      selected: isSel,
                      selectedColor: AppColors.accentTeal,
                      backgroundColor: Colors.white10,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedLeague = l);
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 8),

            // Tab Content
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildMatchesList(filteredMatches)
                  : _selectedTabIndex == 1
                      ? _buildMatchesList(myMatches, emptyMsg: 'No matches for your favourite teams')
                      : _buildStandingsTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTabIndex = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchesList(List<Map<String, dynamic>> matches, {String emptyMsg = 'No matches found'}) {
    if (matches.isEmpty) {
      return Center(
        child: Text(emptyMsg, style: const TextStyle(color: Colors.white54, fontSize: 14)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: matches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final m = matches[idx];
        return _buildMatchCard(m);
      },
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> m) {
    final isLive = m['status'] == 'live';
    final isUpcoming = m['status'] == 'upcoming';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLive ? AppColors.accentTeal.withValues(alpha: 0.5) : AppColors.glassBorder,
          width: isLive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          // Header: League & Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m['league'], style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isLive ? Colors.red.withValues(alpha: 0.2) : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (isLive) ...[
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isLive ? m['minute'] : isUpcoming ? m['time'] : 'FT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLive ? Colors.red : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Teams & Score
          Row(
            children: [
              // Home Team
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _favouriteTeams.contains(m['home']) ? Icons.star : Icons.star_border,
                        color: _favouriteTeams.contains(m['home']) ? AppColors.accentTeal : Colors.white24,
                        size: 18,
                      ),
                      onPressed: () => _toggleFavourite(m['home']),
                    ),
                    Expanded(
                      child: Text(
                        m['home'],
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Score / VS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isLive ? AppColors.accentTeal.withValues(alpha: 0.2) : Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isUpcoming ? 'VS' : '${m['homeScore']} - ${m['awayScore']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isLive ? AppColors.accentTeal : Colors.white,
                  ),
                ),
              ),

              // Away Team
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        m['away'],
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _favouriteTeams.contains(m['away']) ? Icons.star : Icons.star_border,
                        color: _favouriteTeams.contains(m['away']) ? AppColors.accentTeal : Colors.white24,
                        size: 18,
                      ),
                      onPressed: () => _toggleFavourite(m['away']),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Premier League Standings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(width: 24, child: Text('#', style: TextStyle(color: Colors.white38, fontSize: 12))),
              Expanded(child: Text('Club', style: TextStyle(color: Colors.white38, fontSize: 12))),
              SizedBox(width: 28, child: Text('PL', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12))),
              SizedBox(width: 28, child: Text('GD', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12))),
              SizedBox(width: 32, child: Text('PTS', textAlign: TextAlign.center, style: TextStyle(color: AppColors.accentTeal, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _standings.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 12),
              itemBuilder: (context, idx) {
                final s = _standings[idx];
                return Row(
                  children: [
                    SizedBox(width: 24, child: Text('${s['pos']}', style: TextStyle(color: s['pos'] <= 4 ? AppColors.accentTeal : Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                    Expanded(child: Text(s['team'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
                    SizedBox(width: 28, child: Text('${s['p']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    SizedBox(width: 28, child: Text('${s['gd']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                    SizedBox(width: 32, child: Text('${s['pts']}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
