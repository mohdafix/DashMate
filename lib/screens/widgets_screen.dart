import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  static const MethodChannel _browserChannel = MethodChannel('drivedeck/car_browser');

  static const int _gridCols = 12;
  static const int _gridRows = 8;

  // Selected widget and inspector tab
  String _selectedId = 'clock';
  String _activeTab = 'Size'; // 'Size', 'Style', 'Content'

  // Drag state
  bool _isDragging = false;
  int _dragStartGridX = 1;
  int _dragStartGridY = 1;
  Offset _dragAccumulator = Offset.zero;

  // Corner resize state
  bool _isResizing = false;
  int _resizeStartW = 1;
  int _resizeStartH = 1;
  Offset _resizeAccumulator = Offset.zero;

  // Car connection details
  String _headUnitName = 'Google Desktop Head Unit';
  String _headUnitRes = '1190×480';
  String _activeCarLayoutName = 'Google Desktop Head Unit';
  List<Map<String, dynamic>> _savedCarLayouts = [];

  String _currentSongTitle = '';
  String _currentSongArtist = '';
  String _currentSongApp = '';
  String? _currentCoverUrl;

  // Presets definition
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

  // Active placed widgets
  List<Map<String, dynamic>> _widgets = [
    {'id': 'clock', 'x': 1, 'y': 1, 'w': 6, 'h': 4, 'text': 1.0, 'ta': 'left'},
    {'id': 'prayer', 'x': 7, 'y': 1, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'},
    {'id': 'weather', 'x': 10, 'y': 1, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'},
    {'id': 'sports', 'x': 7, 'y': 3, 'w': 6, 'h': 2, 'text': 1.0, 'ta': 'left'},
    {'id': 'music', 'x': 1, 'y': 5, 'w': 8, 'h': 2, 'text': 1.0, 'ta': 'left'},
    {'id': 'speed', 'x': 9, 'y': 5, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'center'},
    {'id': 'shortcuts', 'x': 11, 'y': 5, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'center'},
    {'id': 'fuel', 'x': 1, 'y': 7, 'w': 6, 'h': 2, 'text': 1.0, 'ta': 'left'},
  ];

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onStateUpdate' && call.arguments != null) {
        _updateFromStateJson(call.arguments.toString());
      }
    });
    _loadLayout();
    _loadState();
    _loadSavedCarLayouts();
    _fetchCarInfo();
  }

  void _fetchCarInfo() async {
    try {
      final info = await _browserChannel.invokeMethod('carInfo');
      if (info is Map && mounted) {
        setState(() {
          if (info['scr_name'] != null) {
            _headUnitName = info['scr_name'].toString();
          }
          final w = info['scr_w'] ?? 1190;
          final h = info['scr_h'] ?? 480;
          _headUnitRes = '$w×$h';
        });
      }
    } catch (_) {}
  }

  void _loadSavedCarLayouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('saved_car_layouts_list');
      if (savedStr != null && savedStr.isNotEmpty) {
        final list = jsonDecode(savedStr) as List;
        setState(() {
          _savedCarLayouts = List<Map<String, dynamic>>.from(
            list.map((e) => Map<String, dynamic>.from(e)),
          );
        });
      } else {
        // Initial defaults
        _savedCarLayouts = [
          {
            'name': 'Chery Automobile Co.,Ltd CHERY23-D12.3 G7',
            'res': '1785×690',
            'layout': [
              {'id': 'clock', 'x': 1, 'y': 1, 'w': 6, 'h': 4, 'text': 1.0, 'ta': 'left'},
              {'id': 'prayer', 'x': 7, 'y': 1, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'},
              {'id': 'weather', 'x': 10, 'y': 1, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'},
              {'id': 'sports', 'x': 7, 'y': 3, 'w': 6, 'h': 2, 'text': 1.0, 'ta': 'left'},
              {'id': 'music', 'x': 1, 'y': 5, 'w': 8, 'h': 2, 'text': 1.0, 'ta': 'left'},
              {'id': 'speed', 'x': 9, 'y': 5, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'center'},
              {'id': 'shortcuts', 'x': 11, 'y': 5, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'center'},
              {'id': 'fuel', 'x': 1, 'y': 7, 'w': 6, 'h': 2, 'text': 1.0, 'ta': 'left'},
            ],
          },
          {
            'name': 'Google Desktop Head Unit',
            'res': '1190×480',
            'layout': List<Map<String, dynamic>>.from(_widgets),
          },
        ];
        _persistCarLayouts();
      }
    } catch (_) {}
  }

  void _persistCarLayouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_car_layouts_list', jsonEncode(_savedCarLayouts));
    } catch (_) {}
  }

  void _saveCurrentAsCarLayout(String carName, String resolution) {
    setState(() {
      _activeCarLayoutName = carName;
      _savedCarLayouts.removeWhere((e) => e['name'] == carName);
      _savedCarLayouts.insert(0, {
        'name': carName,
        'res': resolution,
        'layout': List<Map<String, dynamic>>.from(_widgets),
      });
    });
    _persistCarLayouts();
    _saveLayout();
  }

  void _loadCarLayout(Map<String, dynamic> item) {
    setState(() {
      _activeCarLayoutName = item['name'] ?? '';
      if (item['layout'] != null && (item['layout'] as List).isNotEmpty) {
        _widgets = List<Map<String, dynamic>>.from(
          (item['layout'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
        if (!_widgets.any((w) => w['id'] == _selectedId)) {
          _selectedId = _widgets.first['id'];
        }
      }
    });
    _saveLayout();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF162132),
        content: Text('Switched to ${item['name']}', style: const TextStyle(color: Color(0xFF1BE3B0))),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _deleteCarLayout(int index) {
    setState(() {
      _savedCarLayouts.removeAt(index);
    });
    _persistCarLayouts();
  }

  void _loadState() async {
    try {
      final res = await _channel.invokeMethod<String>('getState');
      if (res != null && mounted) {
        _updateFromStateJson(res);
      }
    } catch (_) {}
  }

  void _updateFromStateJson(String stateJson) {
    try {
      final map = jsonDecode(stateJson);
      final music = map['music'];
      if (music != null && mounted) {
        setState(() {
          _currentSongTitle = (music['title'] ?? '').toString().trim();
          _currentSongArtist = (music['artist'] ?? '').toString().trim();
          _currentSongApp = (music['app'] ?? '').toString().trim();
          final cover = (music['cover'] ?? music['art'] ?? '').toString().trim();
          _currentCoverUrl = cover.isNotEmpty ? cover : null;
        });
      }
    } catch (_) {}
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
        {'id': 'clock', 'x': 1, 'y': 1, 'w': 6, 'h': 4, 'text': 1.0, 'ta': 'left'},
        {'id': 'prayer', 'x': 7, 'y': 1, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'},
        {'id': 'weather', 'x': 10, 'y': 1, 'w': 3, 'h': 2, 'text': 1.0, 'ta': 'left'},
        {'id': 'sports', 'x': 7, 'y': 3, 'w': 6, 'h': 2, 'text': 1.0, 'ta': 'left'},
        {'id': 'music', 'x': 1, 'y': 5, 'w': 8, 'h': 2, 'text': 1.0, 'ta': 'left'},
        {'id': 'speed', 'x': 9, 'y': 5, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'center'},
        {'id': 'shortcuts', 'x': 11, 'y': 5, 'w': 2, 'h': 2, 'text': 1.0, 'ta': 'center'},
        {'id': 'fuel', 'x': 1, 'y': 7, 'w': 6, 'h': 2, 'text': 1.0, 'ta': 'left'},
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

  // Detect collision / overlap with other widgets or screen boundary
  bool _isColliding(Map<String, dynamic> target) {
    final int tx1 = target['x'] as int;
    final int ty1 = target['y'] as int;
    final int tw = target['w'] as int;
    final int th = target['h'] as int;
    final int tx2 = tx1 + tw;
    final int ty2 = ty1 + th;

    if (tx1 < 1 || ty1 < 1 || tx2 - 1 > _gridCols || ty2 - 1 > _gridRows) {
      return true;
    }

    for (final other in _widgets) {
      if (other['id'] == target['id']) continue;
      final int ox1 = other['x'] as int;
      final int oy1 = other['y'] as int;
      final int ow = other['w'] as int;
      final int oh = other['h'] as int;
      final int ox2 = ox1 + ow;
      final int oy2 = oy1 + oh;

      if (ox1 < tx2 && ox2 > tx1 && oy1 < ty2 && oy2 > ty1) {
        return true;
      }
    }
    return false;
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

  void _showSavedCarLayoutsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101724),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Saved car layouts',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Save this Home for the car you\'re using. When that car connects again, DashMate switches to its layout by itself.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSub, height: 1.35),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1BE3B0),
                        foregroundColor: const Color(0xFF090E17),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.directions_car, size: 20),
                      label: Text(
                        'Save for this car · $_headUnitName',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        _saveCurrentAsCarLayout(_headUnitName, _headUnitRes);
                        setSheetState(() {});
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF162132),
                            content: Text('Layout saved for $_headUnitName', style: const TextStyle(color: Color(0xFF1BE3B0))),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _savedCarLayouts.length,
                      separatorBuilder: (_, _) => const Divider(color: Color(0xFF1C2738), height: 1),
                      itemBuilder: (context, idx) {
                        final item = _savedCarLayouts[idx];
                        final bool isActive = item['name'] == _activeCarLayoutName;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: isActive
                              ? const Icon(Icons.check_circle, color: Color(0xFF1BE3B0), size: 26)
                              : const Icon(Icons.grid_view_rounded, color: Colors.white54, size: 24),
                          title: Text(
                            item['name'] ?? 'Car Layout',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item['res'] ?? '1190×480',
                            style: const TextStyle(color: AppColors.textSub, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _loadCarLayout(item);
                                  setSheetState(() {});
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Use',
                                  style: TextStyle(
                                    color: Color(0xFF1BE3B0),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
                                onPressed: () {
                                  _deleteCarLayout(idx);
                                  setSheetState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
            onPressed: _showSavedCarLayoutsSheet,
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
            // Top Preview Frame
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
                          // 1. Subtle Background Grid Cells (Matches Screenshot 3)
                          for (int r = 0; r < _gridRows; r++)
                            for (int c = 0; c < _gridCols; c++)
                              Positioned(
                                left: c * wUnit + 1.5,
                                top: r * hUnit + 1.5,
                                width: wUnit - 3,
                                height: hUnit - 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F1522).withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),

                          // 2. Placed Widgets
                          ..._widgets.map((w) {
                            final bool isSel = w['id'] == _selectedId;
                            final bool colliding = isSel && _isColliding(w);
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
                                onPanStart: (details) {
                                  setState(() {
                                    _isDragging = true;
                                    _dragStartGridX = w['x'] as int;
                                    _dragStartGridY = w['y'] as int;
                                    _dragAccumulator = Offset.zero;
                                  });
                                  if (_selectedId != w['id']) {
                                    _selectWidget(w['id']);
                                  }
                                },
                                onPanUpdate: (details) {
                                  _dragAccumulator += details.delta;
                                  final deltaGridX = (_dragAccumulator.dx / wUnit).round();
                                  final deltaGridY = (_dragAccumulator.dy / hUnit).round();
                                  final newX = (_dragStartGridX + deltaGridX).clamp(1, _gridCols - (w['w'] as int) + 1);
                                  final newY = (_dragStartGridY + deltaGridY).clamp(1, _gridRows - (w['h'] as int) + 1);

                                  if (newX != w['x'] || newY != w['y']) {
                                    setState(() {
                                      w['x'] = newX;
                                      w['y'] = newY;
                                    });
                                    _saveLayout();
                                  }
                                },
                                onPanEnd: (_) {
                                  setState(() {
                                    _isDragging = false;
                                  });
                                  _saveLayout();
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: colliding
                                            ? const Color(0x55FF3B30)
                                            : const Color(0xFF121824).withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colliding
                                              ? const Color(0xFFFF453A)
                                              : (isSel ? const Color(0xFF1BE3B0) : const Color(0xFF222C3C)),
                                          width: isSel ? 2.0 : 1.0,
                                        ),
                                        boxShadow: isSel
                                            ? [
                                                BoxShadow(
                                                  color: colliding
                                                      ? const Color(0x66FF3B30)
                                                      : const Color(0xFF1BE3B0).withValues(alpha: 0.35),
                                                  blurRadius: 10,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: _buildWidgetPreview(w['id']),
                                    ),

                                    // Center Dimension badge during drag, resize, or collision (Matches Screenshot 3)
                                    if (isSel && (_isDragging || _isResizing || colliding))
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.7),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: colliding ? const Color(0xFFFF453A) : const Color(0xFF1BE3B0),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Text(
                                            '${w['w']} × ${w['h']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          // 3. Independent Top-Level Resize Handle
                          // Decoupled from widget bounds so touch target is huge (56x56 dp) and never clipped!
                          if (selected != null) ...[
                            Builder(
                              builder: (context) {
                                final double cornerX = ((selected['x'] as int) + (selected['w'] as int) - 1) * wUnit;
                                final double cornerY = ((selected['y'] as int) + (selected['h'] as int) - 1) * hUnit;
                                const double handleHitSize = 56.0;

                                return Positioned(
                                  left: cornerX - (handleHitSize / 2),
                                  top: cornerY - (handleHitSize / 2),
                                  width: handleHitSize,
                                  height: handleHitSize,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onPanStart: (details) {
                                      setState(() {
                                        _isResizing = true;
                                        _resizeStartW = selected['w'] as int;
                                        _resizeStartH = selected['h'] as int;
                                        _resizeAccumulator = Offset.zero;
                                      });
                                    },
                                    onPanUpdate: (details) {
                                      _resizeAccumulator += details.delta;
                                      final int deltaW = (_resizeAccumulator.dx / wUnit).round();
                                      final int deltaH = (_resizeAccumulator.dy / hUnit).round();
                                      final int newW = (_resizeStartW + deltaW).clamp(1, _gridCols - (selected['x'] as int) + 1);
                                      final int newH = (_resizeStartH + deltaH).clamp(1, _gridRows - (selected['y'] as int) + 1);

                                      if (newW != selected['w'] || newH != selected['h']) {
                                        setState(() {
                                          selected['w'] = newW;
                                          selected['h'] = newH;
                                        });
                                        _saveLayout();
                                      }
                                    },
                                    onPanEnd: (_) {
                                      setState(() {
                                        _isResizing = false;
                                      });
                                      _saveLayout();
                                    },
                                    child: Center(
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1BE3B0),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.55),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                          border: Border.all(color: const Color(0xFF060911), width: 1.5),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.open_in_full_rounded,
                                            size: 16,
                                            color: Color(0xFF090E17),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Instruction Subtitle
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

            // Horizontal Carousel of Widgets
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _allWidgetsMeta.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final meta = _allWidgetsMeta[index];
                  final isSel = meta['id'] == _selectedId;

                  return InkWell(
                    onTap: () {
                      if (!_widgets.any((w) => w['id'] == meta['id']) && meta['id'] != 'screen') {
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

            // Inspector Header: Icon + Title + Delete Trash Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _allWidgetsMeta.firstWhere((e) => e['id'] == _selectedId, orElse: () => {'icon': Icons.widgets})['icon'] as IconData,
                        color: const Color(0xFF1BE3B0),
                        size: 24,
                      ),
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

            // Segment Tabs Pill: [ Size ] [ Style ] [ Content ]
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

            // TAB CONTENT: SIZE
            if (_activeTab == 'Size') ...[
              // 2x3 Grid of Presets
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

              // Move Controls Pill: "Move [←] [↑] [↓] [→]"
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

              // Width Stepper Slider: "[⇄] Width [Slider] 8/12"
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

              const SizedBox(height: 12),

              // Height Stepper Slider: "[⇅] Height [Slider] 4/8"
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
                      const Icon(Icons.height, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Text('Height', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: currentH.toDouble().clamp(1.0, 8.0),
                          min: 1.0,
                          max: 8.0,
                          divisions: 7,
                          activeColor: const Color(0xFF1BE3B0),
                          inactiveColor: const Color(0xFF223044),
                          onChanged: (val) {
                            _applySizePreset(currentW, val.round());
                          },
                        ),
                      ),
                      Text('$currentH/8', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)),
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
                      Text('Dynamic live content synced from vehicle sensors, Open-Meteo, JAKIM, and YouTube Music/Spotify.', style: TextStyle(color: AppColors.textSub, fontSize: 12)),
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

  Widget _buildThumbnail() {
    if (_currentCoverUrl != null && _currentCoverUrl!.isNotEmpty) {
      if (_currentCoverUrl!.startsWith('data:image/')) {
        try {
          final base64Str = _currentCoverUrl!.contains(',') ? _currentCoverUrl!.split(',').last : _currentCoverUrl!;
          return Image.memory(base64Decode(base64Str), fit: BoxFit.cover);
        } catch (_) {}
      } else if (_currentCoverUrl!.startsWith('http://') || _currentCoverUrl!.startsWith('https://')) {
        return Image.network(_currentCoverUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, color: Colors.white54, size: 20));
      }
    }
    return const Icon(Icons.music_note, color: Colors.white54, size: 20);
  }

  Widget _buildWidgetPreview(String id) {
    switch (id) {
      case 'clock':
        return const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('08:29', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
                Text('Saturday, 24 Oct', style: TextStyle(fontSize: 8, color: Colors.white70)),
              ],
            ),
          ),
        );
      case 'music':
        final hasMusic = _currentSongTitle.isNotEmpty && _currentSongTitle != "Not Playing";
        final title = hasMusic ? _currentSongTitle : 'Waiting for music...';
        final artist = hasMusic ? _currentSongArtist : (_currentSongApp.isNotEmpty ? 'Play something in $_currentSongApp' : 'Play something in YouTube Music or Spotify');
        return Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                  child: _buildThumbnail(),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1),
                    Text(artist, style: const TextStyle(fontSize: 8, color: Colors.white70), maxLines: 1),
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
              ],
            ),
          ),
        );
      case 'weather':
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
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
          ),
        );
      case 'prayer':
        return const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Zohar 13:00', style: TextStyle(fontSize: 8, color: Colors.white70)),
                Text('4:30:56', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF5EF2D6))),
              ],
            ),
          ),
        );
      case 'sports':
        return const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('1 - 0\nFT Ku...', textAlign: TextAlign.center, style: TextStyle(fontSize: 8, color: Colors.white70)),
          ),
        );
      case 'speed':
        return const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('4', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('km/h', style: TextStyle(fontSize: 7, color: Colors.white54)),
              ],
            ),
          ),
        );
      case 'shortcuts':
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFFFF0033), shape: BoxShape.circle), child: const Icon(Icons.play_arrow, size: 9, color: Colors.white)),
                const SizedBox(width: 4),
                Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFF0072CE), shape: BoxShape.circle), child: const Icon(Icons.live_tv, size: 9, color: Colors.white)),
              ],
            ),
          ),
        );
      case 'fuel':
        return const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('⛽ RON95 2.05 · RON97 3.19 · Diesel 2.95', style: TextStyle(fontSize: 7, color: Colors.white70)),
          ),
        );
      default:
        return Center(child: Text(id.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.white70)));
    }
  }
}
