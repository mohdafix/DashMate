import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    'NBA',
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
      'venue': 'Santiago BernabÃ©u',
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
  ];

  final List<Map<String, dynamic>> _standings = [
    {'pos': 1, 'team': 'Arsenal', 'p': 28, 'w': 20, 'd': 4, 'l': 4, 'gd': '+38', 'pts': 64},
    {'pos': 2, 'team': 'Liverpool', 'p': 28, 'w': 19, 'd': 6, 'l': 3, 'gd': '+35', 'pts': 63},
    {'pos': 3, 'team': 'Man City', 'p': 28, 'w': 19, 'd': 5, 'l': 4, 'gd': '+33', 'pts': 62},
    {'pos': 4, 'team': 'Aston Villa', 'p': 29, 'w': 17, 'd': 4, 'l': 8, 'gd': '+18', 'pts': 55},
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
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

            // Tab Body View
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildGamesTab(filteredMatches)
                  : _selectedTabIndex == 1
                      ? _buildMyTeamsTab(myMatches)
                      : _buildTablesTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSel = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTabIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppColors.accentTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSel ? Colors.black : Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.black : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGamesTab(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text('No matches scheduled in this league today', style: TextStyle(color: AppColors.textSub)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        return _buildMatchCard(list[idx]);
      },
    );
  }

  Widget _buildMyTeamsTab(List<Map<String, dynamic>> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pinned Clubs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${_favouriteTeams.length} selected', style: const TextStyle(fontSize: 12, color: AppColors.accentTeal)),
            ],
          ),
        ),
        // Favourite Teams Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Arsenal',
              'Liverpool',
              'Man City',
              'Chelsea',
              'Man United',
              'Real Madrid',
              'Barcelona',
              'JDT',
              'Selangor FC',
            ].map((team) {
              final isFav = _favouriteTeams.contains(team);
              return FilterChip(
                label: Text(team),
                selected: isFav,
                selectedColor: AppColors.accentTeal.withValues(alpha: 0.25),
                backgroundColor: Colors.white10,
                checkmarkColor: AppColors.accentTeal,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isFav ? FontWeight.bold : FontWeight.normal,
                  color: isFav ? AppColors.accentTeal : Colors.white70,
                ),
                onSelected: (_) => _toggleFavourite(team),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text("My Teams' Games", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const Center(
                  child: Text('No upcoming games for your selected teams', style: TextStyle(color: AppColors.textSub)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) => _buildMatchCard(list[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildTablesTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Premier League Standings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('2025/2026', style: TextStyle(fontSize: 12, color: AppColors.textSub)),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              // Header
              Row(
                children: const [
                  SizedBox(width: 24, child: Text('#', style: TextStyle(fontSize: 11, color: AppColors.textSub, fontWeight: FontWeight.bold))),
                  Expanded(flex: 5, child: Text('Club', style: TextStyle(fontSize: 11, color: AppColors.textSub, fontWeight: FontWeight.bold))),
                  SizedBox(width: 28, child: Text('PL', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textSub))),
                  SizedBox(width: 28, child: Text('GD', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.textSub))),
                  SizedBox(width: 32, child: Text('PTS', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.accentTeal, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 8),
              ..._standings.map((s) {
                final isFav = _favouriteTeams.contains(s['team']);
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isFav ? AppColors.accentTeal.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${s['pos']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: s['pos'] <= 4 ? AppColors.accentTeal : Colors.white70,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(
                          s['team'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isFav ? FontWeight.bold : FontWeight.w500,
                            color: isFav ? AppColors.accentTeal : Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 28, child: Text('${s['p']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white70))),
                      SizedBox(width: 28, child: Text('${s['gd']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white70))),
                      SizedBox(width: 32, child: Text('${s['pts']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> m) {
    final isLive = m['status'] == 'live';
    final isFT = m['status'] == 'ft';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? AppColors.accentTeal.withValues(alpha: 0.5) : Colors.white12,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header: League name & status pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(m['league'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSub, fontWeight: FontWeight.bold)),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0392B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF4D4D)),
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF4D4D))),
                      const SizedBox(width: 4),
                      Text('LIVE ${m['minute']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF4D4D))),
                    ],
                  ),
                )
              else if (isFT)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('FT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
                )
              else
                Text(m['time'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accentTeal)),
            ],
          ),

          const SizedBox(height: 12),

          // Team Scores Row
          Row(
            children: [
              // Home Team
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      m['home'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _favouriteTeams.contains(m['home']) ? AppColors.accentTeal : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildClubBadge(m['home'] as String),
                  ],
                ),
              ),

              // Score or VS Pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isLive || isFT ? '${m['homeScore']} - ${m['awayScore']}' : 'vs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isLive ? AppColors.accentTeal : Colors.white,
                    ),
                  ),
                ),
              ),

              // Away Team
              Expanded(
                child: Row(
                  children: [
                    _buildClubBadge(m['away'] as String),
                    const SizedBox(width: 8),
                    Text(
                      m['away'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _favouriteTeams.contains(m['away']) ? AppColors.accentTeal : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Venue
          Text(
            m['venue'] as String,
            style: const TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }

  Widget _buildClubBadge(String club) {
    Color bg = const Color(0xFF1E293B);
    String initials = club.substring(0, club.length >= 2 ? 2 : 1).toUpperCase();

    if (club.contains('Arsenal')) {
      bg = const Color(0xFFEF0107);
    } else if (club.contains('Liverpool')) {
      bg = const Color(0xFFC8102E);
    } else if (club.contains('Chelsea')) {
      bg = const Color(0xFF034694);
    } else if (club.contains('City')) {
      bg = const Color(0xFF6CABDD);
    } else if (club.contains('Madrid')) {
      bg = const Color(0xFFEEEEE);
    } else if (club.contains('JDT')) {
      bg = const Color(0xFF003399);
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
