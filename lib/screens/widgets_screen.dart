import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');

  static const int _gridCols = 12;
  static const int _gridRows = 8;

  // Selected widget and inspector tab
  String _selectedId = 'clock';
  String _activeTab = 'Size'; // 'Size', 'Style', 'Content'

  // Presets definition matching Screenshot 1
  final List<Map<String, dynamic>> _sizePresets = [
    {'name': 'Small', 'w': 2, 'h': 2, 'sub': '2 × 2', 'iconType': 'small'},
    {'name': 'Square', 'w': 3, 'h': 3, 'sub': '3 × 3', 'iconType': 'square'},
    {'name': 'Wide', 'w': 6, 'h': 2, 'sub': '6 × 2', 'iconType': 'wide'},
    {'name': 'Tall', 'w': 3, 'h': 6, 'sub': '3 × 6', 'iconType': 'tall'},
    {'name': 'Large', 'w': 6, 'h': 4, 'sub': '6 × 4', 'iconType': 'large'},
    {'name': 'Full width', 'w': 12, 'h': 2, 'sub': '12 × 2', 'iconType': 'full'},
  ];

  // All available widgets for the carousel
  final List<Map<String, dynamic>> _allWidgetsMeta = [
    {'id': 'screen', 'name': 'Screen', 'icon': Icons.tv},
    {'id': 'clock', 'name': 'Clock', 'icon': Icons.access_time},
    {'id': 'prayer', 'name': 'Prayer', 'icon': Icons.mosque_outlined},
    {'id': 'weather', 'name': 'Weather', 'icon': Icons.cloud_outlined},
    {'id': 'sports', 'name': 'Sports', 'icon': Icons.sports_soccer},
    {'id': 'music', 'name': 'Music', 'icon': Icons.music_note},
    {'id': 'speed', 'name': 'Speed', 'icon': Icons.speed},
    {'id': 'shortcuts', 'name': 'Shortcuts', 'icon': Icons.apps},
    {'id': 'fuel', 'name': 'Fuel', 'icon': Icons.local_gas_station},
    {'id': 'air', 'name': 'Air Quality', 'icon': Icons.air},
    {'id': 'radar', 'name': 'Rain Radar', 'icon': Icons.radar},
    {'id': 'calendar', 'name': 'Calendar', 'icon': Icons.calendar_month},
  ];

  // Active placed widgets matching Screenshot 1 layout
  List<Map<String, dynamic>> _widgets = [
    {'id': 'clock', 'x': 1, 'y': 1, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'left'},
    {'id': 'music', 'x': 1, 'y': 3, 'w': 7, 'h': 4, 'text': 1.0, 'ta': 'left'},
    {'id': 'weather', 'x': 9, 'y': 1, 'w': 4, 'h': 2, 'text': 1.0, 'ta': 'left'},
    {'id': 'prayer', 'x': 8, 'y': 3, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'left'},
    {'id': 'sports', 'x': 10, 'y': 3, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'},
    {'id': 'speed', 'x': 8, 'y': 5, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'center'},
    {'id': 'shortcuts', 'x': 10, 'y': 5, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'center'},
    {'id': 'fuel', 'x': 8, 'y': 7, 'w': 5, 'h': 2, 'text': 1.0, 'ta': 'left'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  void _loadLayout() async {
    try {
      final res = await _channel.invokeMethod('getLayoutSettings');
      if (res != null && mounted) {
        final parsed = jsonDecode(res as String);
        if (parsed['widgets'] != null && (parsed['widgets'] as List).isNotEmpty) {
          setState(() {
            _widgets = List<Map<String, dynamic>>.from(
              (parsed['widgets'] as List).map((e) => Map<String, dynamic>.from(e)),
            );
          });
        }
      }
    } catch (_) {}
  }

  void _saveLayout() async {
    final layoutObj = {
      'v': 2,
      'textScale': 1.0,
      'clockFont': 'thin',
      'widgets': _widgets,
    };

    try {
      await _channel.invokeMethod('saveLayoutSettings', {'layout': jsonEncode(layoutObj)});
    } catch (_) {}
  }

  void _resetToDefaults() {
    setState(() {
      _widgets = [
        {'id': 'clock', 'x': 1, 'y': 1, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'left'},
        {'id': 'music', 'x': 1, 'y': 3, 'w': 7, 'h': 4, 'text': 1.0, 'ta': 'left'},
        {'id': 'weather', 'x': 9, 'y': 1, 'w': 4, 'h': 2, 'text': 1.0, 'ta': 'left'},
        {'id': 'prayer', 'x': 8, 'y': 3, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'left'},
        {'id': 'sports', 'x': 10, 'y': 3, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'},
        {'id': 'speed', 'x': 8, 'y': 5, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'center'},
        {'id': 'shortcuts', 'x': 10, 'y': 5, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'center'},
        {'id': 'fuel', 'x': 8, 'y': 7, 'w': 5, 'h': 2, 'text': 1.0, 'ta': 'left'},
      ];
      _selectedId = 'clock';
    });
    _saveLayout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Put every widget back to the default layout', style: TextStyle(color: AppColors.tealAccent)),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Map<String, dynamic>? _getSelectedWidget() {
    try {
      return _widgets.firstWhere((e) => e['id'] == _selectedId);
    } catch (_) {
      return null;
    }
  }

  void _selectWidget(String id) {
    setState(() {
      _selectedId = id;
    });
    _channel.invokeMethod('highlightWidget', {'id': id});
  }

  void _moveSelected(int dx, int dy) {
    final w = _getSelectedWidget();
    if (w == null) return;

    final int width = w['w'] ?? 2;
    final int height = w['h'] ?? 2;
    int newX = (w['x'] as int) + dx;
    int newY = (w['y'] as int) + dy;

    if (newX < 1) newX = 1;
    if (newY < 1) newY = 1;
    if (newX + width - 1 > _gridCols) newX = _gridCols - width + 1;
    if (newY + height - 1 > _gridRows) newY = _gridRows - height + 1;

    setState(() {
      w['x'] = newX;
      w['y'] = newY;
    });
    _saveLayout();
  }

  void _applySizePreset(int targetW, int targetH) {
    final w = _getSelectedWidget();
    if (w == null) return;

    int newX = w['x'] as int;
    int newY = w['y'] as int;

    // Boundary adjust if preset exceeds grid bounds
    if (newX + targetW - 1 > _gridCols) {
      newX = _gridCols - targetW + 1;
      if (newX < 1) newX = 1;
    }
    if (newY + targetH - 1 > _gridRows) {
      newY = _gridRows - targetH + 1;
      if (newY < 1) newY = 1;
    }

    setState(() {
      w['x'] = newX;
      w['y'] = newY;
      w['w'] = targetW;
      w['h'] = targetH;
    });
    _saveLayout();
  }

  void _deleteSelectedWidget() {
    if (_selectedId == 'screen') return;
    setState(() {
      _widgets.removeWhere((e) => e['id'] == _selectedId);
      if (_widgets.isNotEmpty) {
        _selectedId = _widgets.first['id'];
      } else {
        _selectedId = 'screen';
      }
    });
    _saveLayout();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _getSelectedWidget();
    final String currentTitle = _allWidgetsMeta.firstWhere(
      (e) => e['id'] == _selectedId,
      orElse: () => {'name': _selectedId.toUpperCase()},
    )['name'];

    final int currentW = selected?['w'] ?? 2;
    final int currentH = selected?['h'] ?? 2;

    return Scaffold(
      backgroundColor: const Color(0xFF0B101B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit widgets',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_outlined, color: Colors.white, size: 24),
            tooltip: 'Saved car layouts',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.surface,
                  content: Text('Layout saved for this car', style: TextStyle(color: AppColors.tealAccent)),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            tooltip: 'Reset layout',
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Preview Frame (Matches Screenshot 1 & 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: AspectRatio(
                aspectRatio: 1190 / 480, // Match exact car aspect ratio
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF060911),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E2838), width: 1.5),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double wUnit = constraints.maxWidth / _gridCols;
                      final double hUnit = constraints.maxHeight / _gridRows;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Placed Widgets
                          ..._widgets.map((w) {
                            final bool isSel = w['id'] == _selectedId;
                            final double left = ((w['x'] as int) - 1) * wUnit + 2;
                            final double top = ((w['y'] as int) - 1) * hUnit + 2;
                            final double width = (w['w'] as int) * wUnit - 4;
                            final double height = (w['h'] as int) * hUnit - 4;

                            return Positioned(
                              left: left,
                              top: top,
                              width: width,
                              height: height,
                              child: GestureDetector(
                                onTap: () => _selectWidget(w['id']),
                                onPanUpdate: (details) {
                                  final int newX = ((left + details.delta.dx) / wUnit).round() + 1;
                                  final int newY = ((top + details.delta.dy) / hUnit).round() + 1;
                                  if (newX >= 1 && newX + (w['w'] as int) - 1 <= _gridCols &&
                                      newY >= 1 && newY + (w['h'] as int) - 1 <= _gridRows) {
                                    setState(() {
                                      w['x'] = newX;
                                      w['y'] = newY;
                                      _selectedId = w['id'];
                                    });
                                    _saveLayout();
                                  }
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF121824).withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSel ? const Color(0xFF1BE3B0) : const Color(0xFF222C3C),
                                          width: isSel ? 2.0 : 1.0,
                                        ),
                                        boxShadow: isSel
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF1BE3B0).withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: _buildWidgetPreview(w['id']),
                                    ),

                                    // Floating Teal Resize Corner Handle (Matches Screenshot 1)
                                    if (isSel)
                                      Positioned(
                                        right: -8,
                                        bottom: -8,
                                        child: GestureDetector(
                                          onPanUpdate: (details) {
                                            if (details.delta.dx > 15 && (w['w'] as int) < _gridCols) {
                                              _applySizePreset((w['w'] as int) + 1, w['h'] as int);
                                            } else if (details.delta.dx < -15 && (w['w'] as int) > 1) {
                                              _applySizePreset((w['w'] as int) - 1, w['h'] as int);
                                            }
                                            if (details.delta.dy > 15 && (w['h'] as int) < _gridRows) {
                                              _applySizePreset(w['w'] as int, (w['h'] as int) + 1);
                                            } else if (details.delta.dy < -15 && (w['h'] as int) > 1) {
                                              _applySizePreset(w['w'] as int, (w['h'] as int) - 1);
                                            }
                                          },
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF1BE3B0),
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
                                            ),
                                            child: const Icon(Icons.open_in_full, size: 13, color: Colors.black),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Instruction Subtitle (Matches Screenshot 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Text(
                  'Drag a widget to move it · drag ◢ to resize · tap to edit',
                  style: TextStyle(fontSize: 12, color: AppColors.textSub, letterSpacing: 0.1),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Horizontal Carousel of Widgets (Matches Screenshot 1)
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allWidgetsMeta.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final meta = _allWidgetsMeta[index];
                  final isSel = meta['id'] == _selectedId;

                  return InkWell(
                    onTap: () {
                      if (!_widgets.any((w) => w['id'] == meta['id']) && meta['id'] != 'screen') {
                        // Place widget if unplaced
                        setState(() {
                          _widgets.add({'id': meta['id'], 'x': 1, 'y': 1, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'});
                        });
                        _saveLayout();
                      }
                      _selectWidget(meta['id']);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 78,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF0F2625) : const Color(0xFF121824),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSel ? const Color(0xFF1BE3B0) : const Color(0xFF1F2B3B),
                          width: isSel ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            meta['icon'] as IconData,
                            color: isSel ? const Color(0xFF1BE3B0) : Colors.white70,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meta['name'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSel ? const Color(0xFF1BE3B0) : Colors.white70,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Inspector Header: Icon + Title + Delete Trash Icon (Matches Screenshot 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF1BE3B0), size: 24),
                      const SizedBox(width: 10),
                      Text(
                        currentTitle,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 22),
                    tooltip: 'Remove',
                    onPressed: _deleteSelectedWidget,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Segment Tabs Pill: [ Size ] [ Style ] [ Content ] (Matches Screenshot 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF121927),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF222F42)),
                ),
                child: Row(
                  children: ['Size', 'Style', 'Content'].map((tab) {
                    final isTab = _activeTab == tab;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = tab),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isTab ? const Color(0xFF223C3A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              tab,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isTab ? const Color(0xFF5EF2D6) : AppColors.textSub,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // TAB CONTENT: SIZE (Matches Screenshot 1 exactly)
            if (_activeTab == 'Size') ...[
              // 2x3 Grid of Presets (Small, Square, Wide, Tall, Large, Full width)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: _sizePresets.length,
                  itemBuilder: (context, index) {
                    final p = _sizePresets[index];
                    final bool isPresetActive = currentW == p['w'] && currentH == p['h'];

                    return InkWell(
                      onTap: () => _applySizePreset(p['w'] as int, p['h'] as int),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161F2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPresetActive ? const Color(0xFF1BE3B0) : const Color(0xFF223044),
                            width: isPresetActive ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Graphic Diagram Box
                            _buildPresetGraphic(p['iconType'] as String, isPresetActive),
                            Text(
                              p['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            Text(
                              p['sub'] as String,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSub),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Move Controls Pill: "Move [←] [↑] [↓] [→]" (Matches Screenshot 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A26),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFF1E2838)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Move',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const Spacer(),
                      _buildMoveArrow(Icons.arrow_back, () => _moveSelected(-1, 0)),
                      const SizedBox(width: 8),
                      _buildMoveArrow(Icons.arrow_upward, () => _moveSelected(0, -1)),
                      const SizedBox(width: 8),
                      _buildMoveArrow(Icons.arrow_downward, () => _moveSelected(0, 1)),
                      const SizedBox(width: 8),
                      _buildMoveArrow(Icons.arrow_forward, () => _moveSelected(1, 0)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Width Stepper Slider: "[⇄] Width [Slider] 2/12" (Matches Screenshot 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A26),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFF1E2838)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text('Width', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: currentW.toDouble().clamp(1.0, 12.0),
                          min: 1.0,
                          max: 12.0,
                          divisions: 11,
                          activeColor: const Color(0xFF1BE3B0),
                          inactiveColor: const Color(0xFF223044),
                          onChanged: (val) {
                            _applySizePreset(val.round(), currentH);
                          },
                        ),
                      ),
                      Text('$currentW/12', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],

            // TAB CONTENT: STYLE
            if (_activeTab == 'Style') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E2838)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Text Alignment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildAlignBtn('Left', Icons.format_align_left, selected?['ta'] == 'left', () {
                            setState(() => selected?['ta'] = 'left');
                            _saveLayout();
                          }),
                          const SizedBox(width: 10),
                          _buildAlignBtn('Center', Icons.format_align_center, selected?['ta'] == 'center', () {
                            setState(() => selected?['ta'] = 'center');
                            _saveLayout();
                          }),
                          const SizedBox(width: 10),
                          _buildAlignBtn('Right', Icons.format_align_right, selected?['ta'] == 'right', () {
                            setState(() => selected?['ta'] = 'right');
                            _saveLayout();
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // TAB CONTENT: CONTENT
            if (_activeTab == 'Content') ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E2838)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Widget Content Options', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 8),
                      Text('Dynamic live content synced from vehicle sensors, Open-Meteo, JAKIM, and Spotify.', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFF1E3532),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF1BE3B0), size: 18),
      ),
    );
  }

  Widget _buildAlignBtn(String label, IconData icon, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1E3532) : const Color(0xFF182232),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? const Color(0xFF1BE3B0) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? const Color(0xFF1BE3B0) : Colors.white70),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: active ? const Color(0xFF1BE3B0) : Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetGraphic(String type, bool active) {
    return Container(
      width: 48,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF283446),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          if (type == 'small')
            Positioned(
              left: 2,
              top: 2,
              width: 14,
              height: 12,
              child: Container(decoration: BoxDecoration(color: active ? const Color(0xFF1BE3B0) : Colors.teal, borderRadius: BorderRadius.circular(2))),
            )
          else if (type == 'square')
            Positioned(
              left: 2,
              top: 2,
              width: 18,
              height: 18,
              child: Container(decoration: BoxDecoration(color: active ? const Color(0xFF1BE3B0) : Colors.teal, borderRadius: BorderRadius.circular(2))),
            )
          else if (type == 'wide')
            Positioned(
              left: 2,
              top: 2,
              width: 36,
              height: 10,
              child: Container(decoration: BoxDecoration(color: active ? const Color(0xFF1BE3B0) : Colors.teal, borderRadius: BorderRadius.circular(2))),
            )
          else if (type == 'tall')
            Positioned(
              left: 2,
              top: 2,
              width: 16,
              height: 20,
              child: Container(decoration: BoxDecoration(color: active ? const Color(0xFF1BE3B0) : Colors.teal, borderRadius: BorderRadius.circular(2))),
            )
          else if (type == 'large')
            Positioned(
              left: 2,
              top: 2,
              width: 32,
              height: 18,
              child: Container(decoration: BoxDecoration(color: active ? const Color(0xFF1BE3B0) : Colors.teal, borderRadius: BorderRadius.circular(2))),
            )
          else if (type == 'full')
            Positioned(
              left: 2,
              top: 2,
              right: 2,
              height: 10,
              child: Container(decoration: BoxDecoration(color: active ? const Color(0xFF1BE3B0) : Colors.teal, borderRadius: BorderRadius.circular(2))),
            ),
        ],
      ),
    );
  }

  Widget _buildWidgetPreview(String id) {
    switch (id) {
      case 'clock':
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('08:29', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
              Text('Saturday, 24 Oct', style: TextStyle(fontSize: 8, color: Colors.white70)),
            ],
          ),
        );
      case 'music':
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Waiting for music...', style: TextStyle(fontSize: 8, color: Colors.white54)),
                    const Text('Play something in Spotify', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1),
                    const SizedBox(height: 3),
                    Row(
                      children: const [
                        Icon(Icons.skip_previous, size: 12, color: Colors.white70),
                        SizedBox(width: 4),
                        Icon(Icons.play_circle_fill, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Icon(Icons.skip_next, size: 12, color: Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'weather':
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.beach_access, size: 16, color: Color(0xFF5EBEFF)),
              SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('25°', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Rain in ~45 min', style: TextStyle(fontSize: 7, color: Colors.white70)),
                ],
              ),
            ],
          ),
        );
      case 'prayer':
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Zohar 13:00', style: TextStyle(fontSize: 8, color: Colors.white70)),
              Text('4:30:56', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5EF2D6))),
            ],
          ),
        );
      case 'sports':
        return const Center(
          child: Text('1 - 0\nFT Ku...', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, color: Colors.white70)),
        );
      case 'speed':
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('4', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('km/h', style: TextStyle(fontSize: 7, color: Colors.white54)),
            ],
          ),
        );
      case 'shortcuts':
        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFFFF0033), shape: BoxShape.circle), child: const Icon(Icons.play_arrow, size: 9, color: Colors.white)),
              Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFF0072CE), shape: BoxShape.circle), child: const Icon(Icons.live_tv, size: 9, color: Colors.white)),
            ],
          ),
        );
      case 'fuel':
        return const Center(
          child: Text('⛽ RON95 1.99 · RON97 4.80 · Diesel 5.07', style: TextStyle(fontSize: 7, color: Colors.white70)),
        );
      default:
        return Center(child: Text(id.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white70)));
    }
  }
}
