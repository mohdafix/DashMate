import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

class MenuItemData {
  final String id;
  final String title;
  final IconData icon;
  bool enabled;

  MenuItemData({
    required this.id,
    required this.title,
    required this.icon,
    this.enabled = true,
  });
}

class FloatingMenuScreen extends StatefulWidget {
  const FloatingMenuScreen({super.key});

  @override
  State<FloatingMenuScreen> createState() => _FloatingMenuScreenState();
}

class _FloatingMenuScreenState extends State<FloatingMenuScreen> {
  static const MethodChannel _channel = MethodChannel('com.dashmate.dashmate/channel');
  static const MethodChannel _browserChannel = MethodChannel('drivedeck/car_browser');

  late List<MenuItemData> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      MenuItemData(id: 'home', title: 'Home', icon: Icons.home_outlined, enabled: true),
      MenuItemData(id: 'web', title: 'Browse', icon: Icons.public_outlined, enabled: true),
      MenuItemData(id: 'prayer', title: 'Prayer', icon: Icons.mosque_outlined, enabled: true),
      MenuItemData(id: 'radio', title: 'Radio FM', icon: Icons.radio_outlined, enabled: true),
      MenuItemData(id: 'custom', title: 'Custom page', icon: Icons.view_quilt_outlined, enabled: true),
      MenuItemData(id: 'lyrics', title: 'Lyrics', icon: Icons.speaker_notes_outlined, enabled: true),
    ];
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    List<String>? savedActiveIds;
    List<String>? savedOrderIds;
    try {
      final prefs = await SharedPreferences.getInstance();
      savedActiveIds = prefs.getStringList('car_menu_active_items');
      savedOrderIds = prefs.getStringList('car_menu_order');
    } catch (_) {}

    try {
      final res = await _channel.invokeMethod('getMenuItems') ??
          await _browserChannel.invokeMethod('getMenuItems');
      if (res != null && res is List) {
        savedActiveIds ??= res.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    if (savedActiveIds == null && savedOrderIds == null) return;
    if (!mounted) return;

    final orderToUse = savedOrderIds ?? savedActiveIds ?? _items.map((e) => e.id).toList();
    final activeSet = (savedActiveIds ?? orderToUse).toSet();

    final List<MenuItemData> reordered = [];
    final seen = <String>{};
    for (final id in orderToUse) {
      if (seen.contains(id)) continue;
      seen.add(id);
      final found = _items.firstWhere(
        (item) => item.id == id,
        orElse: () => MenuItemData(id: id, title: id, icon: Icons.circle_outlined),
      );
      found.enabled = activeSet.contains(id);
      reordered.add(found);
    }
    for (final item in _items) {
      if (!seen.contains(item.id)) {
        seen.add(item.id);
        item.enabled = activeSet.contains(item.id);
        reordered.add(item);
      }
    }

    if (reordered.isNotEmpty) {
      setState(() {
        _items = reordered;
      });
    }
  }

  Future<void> _savePrefs() async {
    final activeIds = _items.where((i) => i.enabled).map((i) => i.id).toList();
    final allIds = _items.map((i) => i.id).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('car_menu_active_items', activeIds);
      await prefs.setStringList('car_menu_order', allIds);
    } catch (_) {}
    try {
      await _channel.invokeMethod('setMenuItems', {'items': activeIds});
    } catch (_) {}
    try {
      await _browserChannel.invokeMethod('setMenuItems', {'items': activeIds});
    } catch (_) {}
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
          'Car menu',
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
          // Subtitle / Header Description
          const Text(
            'What the floating DashMate menu on the car shows. Switch items on or off and drag to change the order.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Card with Reorderable List
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                  _savePrefs();
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isLast = index == _items.length - 1;

                  return Container(
                    key: ValueKey(item.id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              // Drag Handle
                              ReorderableDragStartListener(
                                index: index,
                                child: Container(
                                  padding: const EdgeInsets.only(right: 12, left: 2, top: 4, bottom: 4),
                                  color: Colors.transparent,
                                  child: const Icon(
                                    Icons.drag_indicator,
                                    color: Colors.white38,
                                    size: 22,
                                  ),
                                ),
                              ),

                              // Item Icon
                              Icon(
                                item.icon,
                                color: Colors.white,
                                size: 22,
                              ),
                              const SizedBox(width: 14),

                              // Item Title
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              // Toggle Switch
                              Switch(
                                value: item.enabled,
                                activeColor: AppColors.accentTeal,
                                activeTrackColor: const Color(0xFF0F766E),
                                inactiveThumbColor: Colors.white38,
                                inactiveTrackColor: Colors.white12,
                                onChanged: (val) {
                                  setState(() {
                                    item.enabled = val;
                                  });
                                  _savePrefs();
                                },
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 14,
                            endIndent: 14,
                            color: Colors.white10,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
