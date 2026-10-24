import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/localization.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _channel = MethodChannel('com.dashmate.dashmate/channel');
  bool _hasAccess = false;
  List<dynamic> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  void _loadCalendar() async {
    setState(() => _loading = true);
    try {
      final res = await _channel.invokeMethod('getCalendarEvents');
      if (res != null) {
        final parsed = jsonDecode(res as String);
        setState(() {
          _hasAccess = parsed['access'] == true;
          _events = parsed['events'] ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _formatTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return AppLocalizations.get('today');
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (d.year == tomorrow.year && d.month == tomorrow.month && d.day == tomorrow.day) {
      return AppLocalizations.get('tomorrow');
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLocalizations.get('calendar'),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.tealAccent),
            onPressed: _loadCalendar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.tealAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sync Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _hasAccess ? AppColors.tealAccent.withValues(alpha: 0.4) : AppColors.glassBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _hasAccess ? Icons.check_circle : Icons.warning_amber_rounded,
                          color: _hasAccess ? AppColors.tealAccent : Colors.orangeAccent,
                          size: 26,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasAccess ? 'Calendar Synced' : 'Calendar Access Needed',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _hasAccess
                                    ? 'Events automatically broadcast to Android Auto head unit.'
                                    : 'Enable calendar permission in Android settings to sync agenda.',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.get('upcoming_events'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),

                  if (_events.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.event_available, color: AppColors.textMuted, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.get('no_events'),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final ev = _events[index];
                        final String title = ev['title'] ?? 'Event';
                        final String loc = ev['where'] ?? '';
                        final int begin = ev['begin'] ?? 0;
                        final int end = ev['end'] ?? 0;
                        final bool allDay = ev['allDay'] == true;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.tealAccent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          _formatDate(begin),
                                          style: const TextStyle(color: AppColors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          allDay ? 'All Day' : '${_formatTime(begin)} – ${_formatTime(end)}',
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    if (loc.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              loc,
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
