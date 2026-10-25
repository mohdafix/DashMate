import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/car_layout.dart';
import '../theme/app_tokens.dart';

class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  AppTokens get t => context.tokens;

  static const MethodChannel _channel = MethodChannel(
    'com.dashmate.dashmate/channel',
  );

  static const int _gridCols = 12;

  // Two layouts: "wide" (12 × 8, landscape car screens) and "tall" (12 × 18, portrait screens
  // such as the Jaecoo J7). The car uses the one that matches its screen.
  bool _tall = true;
  int get _gridRows => _tall ? 18 : 8;

  static List<Map<String, dynamic>> _tallDefaults() => CarLayout.defaultWidgets(true);
  static List<Map<String, dynamic>> _wideDefaults() => CarLayout.defaultWidgets(false);

  // Page-wide options saved with each layout (clock font, 12/24-hour clock, …), kept as loaded
  // so saving the widgets doesn't wipe what Settings chose.
  Map<String, dynamic> _wideOptions = {};
  Map<String, dynamic> _tallOptions = {};

  // Selected widget and inspector tab
  String _selectedId = 'clock';
  String _activeTab = 'Size'; // 'Size', 'Style', 'Content'

  String _currentSongTitle = '';
  String _currentSongArtist = '';
  String _currentSongApp = '';
  String? _currentCoverUrl;

  // Presets definition matching Screenshot 1
  final List<Map<String, dynamic>> _widePresets = [
    {'name': 'Small', 'w': 2, 'h': 2, 'sub': '2 × 2', 'iconType': 'small'},
    {'name': 'Square', 'w': 3, 'h': 3, 'sub': '3 × 3', 'iconType': 'square'},
    {'name': 'Wide', 'w': 6, 'h': 2, 'sub': '6 × 2', 'iconType': 'wide'},
    {'name': 'Tall', 'w': 3, 'h': 6, 'sub': '3 × 6', 'iconType': 'tall'},
    {'name': 'Large', 'w': 6, 'h': 4, 'sub': '6 × 4', 'iconType': 'large'},
    {
      'name': 'Full width',
      'w': 12,
      'h': 2,
      'sub': '12 × 2',
      'iconType': 'full',
    },
  ];

  // Tall screens: the 12 columns are narrow, so widgets are wider and less tall in cells.
  final List<Map<String, dynamic>> _tallPresets = [
    {'name': 'Small', 'w': 4, 'h': 2, 'sub': '4 × 2', 'iconType': 'small'},
    {'name': 'Half', 'w': 6, 'h': 3, 'sub': '6 × 3', 'iconType': 'square'},
    {'name': 'Banner', 'w': 12, 'h': 2, 'sub': '12 × 2', 'iconType': 'wide'},
    {'name': 'Tall', 'w': 6, 'h': 6, 'sub': '6 × 6', 'iconType': 'tall'},
    {'name': 'Large', 'w': 12, 'h': 5, 'sub': '12 × 5', 'iconType': 'large'},
    {
      'name': 'Full width',
      'w': 12,
      'h': 3,
      'sub': '12 × 3',
      'iconType': 'full',
    },
  ];

  List<Map<String, dynamic>> get _sizePresets =>
      _tall ? _tallPresets : _widePresets;

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

  // Placed widgets, one list per layout; _widgets is the one being edited.
  List<Map<String, dynamic>> _wideWidgets = _wideDefaults();
  List<Map<String, dynamic>> _tallWidgets = _tallDefaults();
  List<Map<String, dynamic>> get _widgets =>
      _tall ? _tallWidgets : _wideWidgets;
  set _widgets(List<Map<String, dynamic>> v) {
    if (_tall) {
      _tallWidgets = v;
    } else {
      _wideWidgets = v;
    }
  }

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
          final cover = (music['cover'] ?? music['art'] ?? '')
              .toString()
              .trim();
          _currentCoverUrl = cover.isNotEmpty ? cover : null;
        });
      }
    } catch (_) {}
  }

  void _loadLayout() async {
    // Start on the layout that matches the car (tall unless a wide car screen was measured).
    try {
      // "Always tall" (Settings › Car layout, the default): the car uses the Tall placement.
      final mode = await _channel.invokeMethod<String>('getLayoutMode');
      final size = await _channel.invokeMethod<String>('getCarScreenSize');
      if (mounted) {
        setState(() => _tall = mode != 'auto' || size == null || !size.contains('landscape'));
      }
    } catch (_) {}
    for (final tall in [false, true]) {
      try {
        final res = await _channel.invokeMethod('getLayoutSettings', {
          'tall': tall,
        });
        if (res == null || !mounted) continue;
        final parsed = jsonDecode(res as String);
        if (parsed is Map) {
          final opts = Map<String, dynamic>.from(parsed)..remove('widgets');
          if (tall) {
            _tallOptions = opts;
          } else {
            _wideOptions = opts;
          }
        }
        if (parsed['widgets'] != null &&
            (parsed['widgets'] as List).isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
            (parsed['widgets'] as List).map(
              (e) => Map<String, dynamic>.from(e),
            ),
          );
          final fixed = _sanitized(list, tall ? 18 : 8);
          setState(() {
            if (tall) {
              _tallWidgets = fixed;
            } else {
              _wideWidgets = fixed;
            }
          });
        }
      } catch (_) {}
    }
    // The saved layout may not have the widget that was selected (e.g. Clock removed): pick one
    // that is there, so Size / Style / Move act on a real widget.
    if (mounted && _getSelectedWidget() == null && _widgets.isNotEmpty) {
      setState(() => _selectedId = _widgets.first['id'] as String);
    }
  }

  void _saveLayout() async {
    final layoutObj = <String, dynamic>{
      'textScale': 1.0,
      'clockFont': 'thin',
      ...(_tall ? _tallOptions : _wideOptions),
      'widgets': _widgets,
    }..['v'] = 2; // the board is the 12-column grid

    try {
      await _channel.invokeMethod('saveLayoutSettings', {
        'layout': jsonEncode(layoutObj),
        'tall': _tall,
      });
    } catch (_) {}
  }

  void _resetToDefaults() {
    setState(() {
      _widgets = _tall ? _tallDefaults() : _wideDefaults();
      _selectedId = 'clock';
    });
    _saveLayout();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Put every widget back to the default layout (this screen shape only)',
        ),
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

  // ---- Placement rules (both screen shapes): inside the grid, never on top of another widget ----

  /// True when [w] fits at (x, y) with size ww × hh: inside the grid and not overlapping others.
  bool _fits(Map<String, dynamic> w, int x, int y, int ww, int hh) {
    if (x < 1 || y < 1 || ww < 1 || hh < 1) return false;
    if (x + ww - 1 > _gridCols || y + hh - 1 > _gridRows) return false;
    for (final o in _widgets) {
      if (identical(o, w)) continue;
      final int ox = o['x'] as int,
          oy = o['y'] as int,
          ow = o['w'] as int,
          oh = o['h'] as int;
      final bool apart =
          x + ww - 1 < ox ||
          ox + ow - 1 < x ||
          y + hh - 1 < oy ||
          oy + oh - 1 < y;
      if (!apart) return false;
    }
    return true;
  }

  /// The free spot for a ww × hh widget closest to (nearX, nearY), or null when there is no room.
  List<int>? _findSpot(
    Map<String, dynamic> w,
    int ww,
    int hh, {
    int nearX = 1,
    int nearY = 1,
  }) {
    List<int>? best;
    int bestD = 1 << 30;
    for (int y = 1; y + hh - 1 <= _gridRows; y++) {
      for (int x = 1; x + ww - 1 <= _gridCols; x++) {
        if (!_fits(w, x, y, ww, hh)) continue;
        final int d = (x - nearX).abs() + (y - nearY).abs() * 2;
        if (d < bestD) {
          bestD = d;
          best = [x, y];
        }
      }
    }
    return best;
  }

  void _noRoom() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No free space for that size. Make another widget smaller or delete one.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Drag state: where the widget started and how far the finger has moved since.
  int _gStartX = 1, _gStartY = 1, _gStartW = 1, _gStartH = 1;
  Offset _gMoved = Offset.zero;

  void _beginGesture(Map<String, dynamic> w) {
    _gStartX = w['x'] as int;
    _gStartY = w['y'] as int;
    _gStartW = w['w'] as int;
    _gStartH = w['h'] as int;
    _gMoved = Offset.zero;
    if (_selectedId != w['id']) _selectWidget(w['id'] as String);
  }

  /// Moves the widget one cell at a time as the finger travels; blocked cells are skipped.
  void _dragMove(
    Map<String, dynamic> w,
    Offset delta,
    double wUnit,
    double hUnit,
  ) {
    _gMoved += delta;
    final int x = _gStartX + (_gMoved.dx / wUnit).round();
    final int y = _gStartY + (_gMoved.dy / hUnit).round();
    if ((x != w['x'] || y != w['y']) &&
        _fits(w, x, y, w['w'] as int, w['h'] as int)) {
      setState(() {
        w['x'] = x;
        w['y'] = y;
      });
    }
  }

  /// Resizes from the bottom-right corner, one cell at a time, within the grid and free space.
  void _dragResize(
    Map<String, dynamic> w,
    Offset delta,
    double wUnit,
    double hUnit,
  ) {
    _gMoved += delta;
    final int ww = (_gStartW + (_gMoved.dx / wUnit).round()).clamp(
      1,
      _gridCols,
    );
    final int hh = (_gStartH + (_gMoved.dy / hUnit).round()).clamp(
      1,
      _gridRows,
    );
    if (ww == w['w'] && hh == w['h']) return;
    final int x = w['x'] as int, y = w['y'] as int;
    // Try both sides changing, then each side alone (so a blocked side doesn't freeze the other).
    for (final size in [
      [ww, hh],
      [ww, w['h'] as int],
      [w['w'] as int, hh],
    ]) {
      if ((size[0] != w['w'] || size[1] != w['h']) &&
          _fits(w, x, y, size[0], size[1])) {
        setState(() {
          w['w'] = size[0];
          w['h'] = size[1];
        });
        return;
      }
    }
  }

  void _endGesture() => _saveLayout();

  void _moveSelected(int dx, int dy) {
    final w = _getSelectedWidget();
    if (w == null) return;
    final int x = (w['x'] as int) + dx;
    final int y = (w['y'] as int) + dy;
    if (!_fits(w, x, y, w['w'] as int, w['h'] as int)) return;
    setState(() {
      w['x'] = x;
      w['y'] = y;
    });
    _saveLayout();
  }

  void _applySizePreset(int targetW, int targetH) {
    final w = _getSelectedWidget();
    if (w == null) return;
    // Keep it where it is if it fits; otherwise the nearest free spot for the new size.
    final int x = w['x'] as int, y = w['y'] as int;
    final List<int>? spot = _fits(w, x, y, targetW, targetH)
        ? [x, y]
        : _findSpot(w, targetW, targetH, nearX: x, nearY: y);
    if (spot == null) {
      _noRoom();
      return;
    }
    setState(() {
      w['x'] = spot[0];
      w['y'] = spot[1];
      w['w'] = targetW;
      w['h'] = targetH;
    });
    _saveLayout();
  }

  /// Older or hand-edited layouts: pull widgets back inside the grid and apart from each other.
  List<Map<String, dynamic>> _sanitized(
    List<Map<String, dynamic>> list,
    int rows,
  ) {
    final placed = <Map<String, dynamic>>[];
    bool clash(Map<String, dynamic> a, Map<String, dynamic> b) =>
        !((a['x'] as int) + (a['w'] as int) - 1 < (b['x'] as int) ||
            (b['x'] as int) + (b['w'] as int) - 1 < (a['x'] as int) ||
            (a['y'] as int) + (a['h'] as int) - 1 < (b['y'] as int) ||
            (b['y'] as int) + (b['h'] as int) - 1 < (a['y'] as int));
    for (final w in list) {
      final int ww = ((w['w'] as num?)?.toInt() ?? 2).clamp(1, _gridCols);
      final int hh = ((w['h'] as num?)?.toInt() ?? 2).clamp(1, rows);
      int x = ((w['x'] as num?)?.toInt() ?? 1).clamp(1, _gridCols - ww + 1);
      int y = ((w['y'] as num?)?.toInt() ?? 1).clamp(1, rows - hh + 1);
      final c = Map<String, dynamic>.from(w)
        ..['x'] = x
        ..['y'] = y
        ..['w'] = ww
        ..['h'] = hh;
      if (placed.any((p) => clash(p, c))) {
        // Find a free place, shrinking it step by step if needed. If there is no room at all,
        // keep it where it was: never silently drop the owner's widget.
        final origX = c['x'], origY = c['y'];
        bool done = false;
        for (int sw = ww, sh = hh; !done && sw >= 1 && sh >= 1;) {
          c['w'] = sw;
          c['h'] = sh;
          for (y = 1; y + sh - 1 <= rows && !done; y++) {
            for (x = 1; x + sw - 1 <= _gridCols && !done; x++) {
              c['x'] = x;
              c['y'] = y;
              if (!placed.any((p) => clash(p, c))) done = true;
            }
          }
          if (sh >= sw && sh > 1) {
            sh--;
          } else {
            sw--;
          }
        }
        if (!done) {
          c['x'] = origX;
          c['y'] = origY;
          c['w'] = ww;
          c['h'] = hh;
        }
      }
      placed.add(c);
    }
    return placed;
  }

  /// Left / Center / Right on the Style tab: stored as `ta` on the selected widget of the
  /// layout being edited (Wide or Tall) and sent to the car straight away.
  void _setAlignment(String ta) {
    final w = _getSelectedWidget();
    if (w == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap a widget on the board first, then pick its alignment.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => w['ta'] = ta);
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
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit widgets',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bookmark_border_outlined,
              color: t.ink,
              size: 24,
            ),
            tooltip: 'Saved car layouts',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Layout saved for this car',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: t.ink, size: 24),
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
            // Which screen shape to edit: tall (Jaecoo J7 portrait) or wide (landscape cars).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildShapeTab(
                      'Tall · Jaecoo J7',
                      Icons.stay_current_portrait,
                      true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildShapeTab(
                      'Wide',
                      Icons.stay_current_landscape,
                      false,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Center(
                child: ConstrainedBox(
                  // A tall board would be taller than the phone; keep it to a comfortable height.
                  constraints: BoxConstraints(
                    maxHeight: _tall ? 460 : double.infinity,
                  ),
                  child: AspectRatio(
                    aspectRatio: _tall
                        ? 1080 / 1920
                        : 1190 / 480, // same shape as the car screen
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: t.border,
                          width: 1.5,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double wUnit = constraints.maxWidth / _gridCols;
                          final double hUnit =
                              constraints.maxHeight / _gridRows;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Placed Widgets
                              ..._widgets.map((w) {
                                final bool isSel = w['id'] == _selectedId;
                                final double left =
                                    ((w['x'] as int) - 1) * wUnit + 2;
                                final double top =
                                    ((w['y'] as int) - 1) * hUnit + 2;
                                final double width =
                                    (w['w'] as int) * wUnit - 4;
                                final double height =
                                    (w['h'] as int) * hUnit - 4;

                                return Positioned(
                                  left: left,
                                  top: top,
                                  width: width,
                                  height: height,
                                  child: GestureDetector(
                                    // The whole tile answers touches, not just its drawn content.
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _selectWidget(w['id']),
                                    onPanStart: (_) => _beginGesture(w),
                                    onPanUpdate: (details) => _dragMove(
                                      w,
                                      details.delta,
                                      wUnit,
                                      hUnit,
                                    ),
                                    onPanEnd: (_) => _endGesture(),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      // The tile fills its cells, so its size on the board is its size in the car.
                                      fit: StackFit.expand,
                                      children: [
                                        Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: t.surface.withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: isSel
                                                  ? t.accent
                                                  : t.border,
                                              width: isSel ? 2.0 : 1.0,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: _buildWidgetPreview(w),
                                        ),

                                        // Floating Teal Resize Corner Handle (Matches Screenshot 1)
                                        if (isSel)
                                          Positioned(
                                            right: -18,
                                            bottom: -18,
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.opaque,
                                              onPanStart: (_) =>
                                                  _beginGesture(w),
                                              onPanUpdate: (details) =>
                                                  _dragResize(
                                                    w,
                                                    details.delta,
                                                    wUnit,
                                                    hUnit,
                                                  ),
                                              onPanEnd: (_) => _endGesture(),
                                              child: Container(
                                                width: 44,
                                                height: 44,
                                                alignment: Alignment.center,
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration:
                                                      BoxDecoration(
                                                        color: t.accent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: Icon(
                                                    Icons.open_in_full,
                                                    size: 13,
                                                    color: t.onAccent,
                                                  ),
                                                ),
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
              ),
            ),

            // Instruction Subtitle (Matches Screenshot 1)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: Text(
                  'Drag a widget to move it · drag ◢ to resize · tap to edit',
                  style: TextStyle(
                    fontSize: 12,
                    color: t.ink2,
                    letterSpacing: 0.1,
                  ),
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
                      if (!_widgets.any((w) => w['id'] == meta['id']) &&
                          meta['id'] != 'screen') {
                        // Place it in the first free spot, trying smaller sizes if the screen is full.
                        final w = <String, dynamic>{
                          'id': meta['id'],
                          'text': 1.0,
                          'ta': 'left',
                        };
                        final sizes = _tall
                            ? [
                                [6, 3],
                                [6, 2],
                                [4, 2],
                                [3, 2],
                                [2, 1],
                              ]
                            : [
                                [3, 2],
                                [2, 2],
                                [2, 1],
                                [1, 1],
                              ];
                        List<int>? spot;
                        List<int> size = sizes.first;
                        for (final s in sizes) {
                          spot = _findSpot(w, s[0], s[1]);
                          if (spot != null) {
                            size = s;
                            break;
                          }
                        }
                        if (spot == null) {
                          _noRoom();
                          return;
                        }
                        setState(() {
                          w['x'] = spot![0];
                          w['y'] = spot[1];
                          w['w'] = size[0];
                          w['h'] = size[1];
                          _widgets.add(w);
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
                        color: isSel
                            ? t.accent.withValues(alpha: 0.12)
                            : t.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSel
                              ? t.accent
                              : t.border,
                          width: isSel ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            meta['icon'] as IconData,
                            color: isSel
                                ? t.accent
                                : t.ink2,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meta['name'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSel
                                  ? t.accent
                                  : t.ink2,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                      Icon(
                        Icons.access_time,
                        color: t.accent,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        currentTitle,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: t.ink2,
                      size: 22,
                    ),
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
                  color: t.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: t.border),
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
                            color: isTab
                                ? t.accent.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              tab,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isTab
                                    ? t.accent
                                    : t.ink2,
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
                    final bool isPresetActive =
                        currentW == p['w'] && currentH == p['h'];

                    return InkWell(
                      onTap: () =>
                          _applySizePreset(p['w'] as int, p['h'] as int),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPresetActive
                                ? t.accent
                                : t.border,
                            width: isPresetActive ? 2.0 : 1.0,
                          ),
                        ),
                        // Scales down instead of overflowing with large system text.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Graphic Diagram Box
                            _buildPresetGraphic(
                              p['iconType'] as String,
                              isPresetActive,
                            ),
                            Text(
                              p['name'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: t.ink,
                              ),
                            ),
                            Text(
                              p['sub'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: t.ink2,
                              ),
                            ),
                          ],
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Move',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: t.ink,
                        ),
                      ),
                      const Spacer(),
                      _buildMoveArrow(
                        Icons.arrow_back,
                        () => _moveSelected(-1, 0),
                      ),
                      const SizedBox(width: 8),
                      _buildMoveArrow(
                        Icons.arrow_upward,
                        () => _moveSelected(0, -1),
                      ),
                      const SizedBox(width: 8),
                      _buildMoveArrow(
                        Icons.arrow_downward,
                        () => _moveSelected(0, 1),
                      ),
                      const SizedBox(width: 8),
                      _buildMoveArrow(
                        Icons.arrow_forward,
                        () => _moveSelected(1, 0),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Width Stepper Slider: "[⇄] Width [Slider] 2/12" (Matches Screenshot 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: t.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        color: t.ink2,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Width',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: t.ink,
                          fontSize: 13,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: currentW.toDouble().clamp(1.0, 12.0),
                          min: 1.0,
                          max: 12.0,
                          divisions: 11,
                          activeColor: t.accent,
                          inactiveColor: t.border,
                          onChanged: (val) {
                            _applySizePreset(val.round(), currentH);
                          },
                        ),
                      ),
                      Text(
                        '$currentW/12',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: t.ink2,
                          fontSize: 13,
                        ),
                      ),
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
                    color: t.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Text Alignment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildAlignBtn(
                            'Left',
                            Icons.format_align_left,
                            selected != null && _taOf(selected) == 'left',
                            () => _setAlignment('left'),
                          ),
                          const SizedBox(width: 10),
                          _buildAlignBtn(
                            'Center',
                            Icons.format_align_center,
                            selected != null && _taOf(selected) == 'center',
                            () => _setAlignment('center'),
                          ),
                          const SizedBox(width: 10),
                          _buildAlignBtn(
                            'Right',
                            Icons.format_align_right,
                            selected != null && _taOf(selected) == 'right',
                            () => _setAlignment('right'),
                          ),
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
                    color: t.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Widget Content Options',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: t.ink,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Dynamic live content synced from vehicle sensors, Open-Meteo, JAKIM, and Spotify.',
                        style: TextStyle(
                          color: t.ink2,
                          fontSize: 12,
                        ),
                      ),
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

  /// One of the two screen-shape tabs above the board.
  Widget _buildShapeTab(String label, IconData icon, bool tall) {
    final bool active = _tall == tall;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (active) return;
        setState(() {
          _tall = tall;
          _selectedId = _widgets.isNotEmpty
              ? _widgets.first['id'] as String
              : 'screen';
        });
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? t.accent : t.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? t.accent : t.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? t.onAccent : t.ink2,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: active ? t.onAccent : t.ink2,
                ),
              ),
            ),
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
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: t.accent, size: 18),
      ),
    );
  }

  Widget _buildAlignBtn(
    String label,
    IconData icon,
    bool active,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        key: ValueKey('align-${label.toLowerCase()}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? t.accent.withValues(alpha: 0.12) : t.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? t.accent : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? t.accent : t.ink2,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: active ? t.accent : t.ink2,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
        color: t.surface2,
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
              child: Container(
                decoration: BoxDecoration(
                  color: active ? t.accent : t.accent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          else if (type == 'square')
            Positioned(
              left: 2,
              top: 2,
              width: 18,
              height: 18,
              child: Container(
                decoration: BoxDecoration(
                  color: active ? t.accent : t.accent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          else if (type == 'wide')
            Positioned(
              left: 2,
              top: 2,
              width: 36,
              height: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: active ? t.accent : t.accent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          else if (type == 'tall')
            Positioned(
              left: 2,
              top: 2,
              width: 16,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: active ? t.accent : t.accent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          else if (type == 'large')
            Positioned(
              left: 2,
              top: 2,
              width: 32,
              height: 18,
              child: Container(
                decoration: BoxDecoration(
                  color: active ? t.accent : t.accent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          else if (type == 'full')
            Positioned(
              left: 2,
              top: 2,
              right: 2,
              height: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: active ? t.accent : t.accent.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (_currentCoverUrl != null && _currentCoverUrl!.isNotEmpty) {
      if (_currentCoverUrl!.startsWith('data:image/')) {
        try {
          final base64Str = _currentCoverUrl!.contains(',')
              ? _currentCoverUrl!.split(',').last
              : _currentCoverUrl!;
          return Image.memory(base64Decode(base64Str), fit: BoxFit.cover);
        } catch (_) {}
      } else if (_currentCoverUrl!.startsWith('http://') ||
          _currentCoverUrl!.startsWith('https://')) {
        return Image.network(
          _currentCoverUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.music_note, color: t.ink3, size: 20),
        );
      }
    }
    return Icon(Icons.music_note, color: t.ink3, size: 20);
  }

  /// The widget's text alignment, as the car reads it (`ta`); speed and shortcuts default to centre.
  static String _taOf(Map<String, dynamic> w) {
    final v = w['ta'];
    if (v == 'left' || v == 'center' || v == 'right') return v as String;
    return (w['id'] == 'speed' || w['id'] == 'shortcuts') ? 'center' : 'left';
  }

  /// A mini version of the car tile, laid out with the widget's text alignment so the
  /// board shows what Left / Center / Right will do on the car.
  Widget _buildWidgetPreview(Map<String, dynamic> w) {
    final String id = w['id'] as String;
    final String ta = _taOf(w);
    final Alignment a = ta == 'center'
        ? Alignment.center
        : (ta == 'right' ? Alignment.centerRight : Alignment.centerLeft);
    final CrossAxisAlignment cross = ta == 'center'
        ? CrossAxisAlignment.center
        : (ta == 'right' ? CrossAxisAlignment.end : CrossAxisAlignment.start);
    final TextAlign tAlign = ta == 'center'
        ? TextAlign.center
        : (ta == 'right' ? TextAlign.right : TextAlign.left);
    Widget fit(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Align(
        alignment: a,
        child: FittedBox(fit: BoxFit.scaleDown, alignment: a, child: child),
      ),
    );
    switch (id) {
      case 'clock':
        return fit(
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: cross,
              children: [
                Text(
                  '08:29',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: t.ink,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Saturday, 24 Oct',
                  style: TextStyle(fontSize: 8, color: t.ink2),
                ),
              ],
            ),
          );
      case 'music':
        final hasMusic =
            _currentSongTitle.isNotEmpty && _currentSongTitle != "Not Playing";
        final title = hasMusic ? _currentSongTitle : 'Waiting for music...';
        final artist = hasMusic
            ? _currentSongArtist
            : (_currentSongApp.isNotEmpty
                  ? 'Play something in $_currentSongApp'
                  : 'Play something in YouTube Music or Spotify');
        return fit(
          Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildThumbnail(),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: cross,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: t.ink,
                      ),
                      maxLines: 1,
                    ),
                    Text(
                      artist,
                      style: TextStyle(
                        fontSize: 8,
                        color: t.ink2,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.skip_previous,
                          size: 12,
                          color: t.ink2,
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.play_circle_fill,
                          size: 16,
                          color: t.ink,
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.skip_next, size: 12, color: t.ink2),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
      case 'weather':
        return fit(
          Row(
              children: [
                Icon(Icons.beach_access, size: 16, color: t.accent),
                SizedBox(width: 4),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: cross,
                  children: [
                    Text(
                      '25°',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      'Rain in ~45 min',
                      style: TextStyle(fontSize: 7, color: t.ink2),
                    ),
                  ],
                ),
              ],
            ),
          );
      case 'prayer':
        return fit(
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: cross,
              children: [
                Text(
                  'Zohar 13:00',
                  style: TextStyle(fontSize: 8, color: t.ink2),
                ),
                Text(
                  '4:30:56',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: t.accent,
                  ),
                ),
              ],
            ),
          );
      case 'sports':
        return fit(
          Text(
              '1 - 0\nFT Ku...',
              textAlign: tAlign,
              style: TextStyle(fontSize: 8, color: t.ink2),
            ),
          );
      case 'speed':
        return fit(
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: cross,
              children: [
                Text(
                  '4',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: t.ink,
                  ),
                ),
                Text(
                  'km/h',
                  style: TextStyle(fontSize: 7, color: t.ink3),
                ),
              ],
            ),
          );
      case 'shortcuts':
        return fit(
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: t.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    size: 9,
                    color: t.ink,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: t.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.live_tv,
                    size: 9,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          );
      case 'fuel':
        return fit(
          Text(
              '⛽ RON95 2.05 · RON97 3.19 · Diesel 2.95',
              style: TextStyle(fontSize: 7, color: t.ink2),
            ),
          );
      default:
        return fit(
          Text(
            id.toUpperCase(),
            style: TextStyle(fontSize: 8, color: t.ink2),
          ),
        );
    }
  }
}
