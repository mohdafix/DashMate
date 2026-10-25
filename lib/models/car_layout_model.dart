import 'dart:convert';

class CarWidgetModel {
  String id;
  int x;
  int y;
  int w;
  int h;
  String? ta;

  CarWidgetModel({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.ta,
  });

  CarWidgetModel copyWith({
    String? id,
    int? x,
    int? y,
    int? w,
    int? h,
    String? ta,
  }) {
    return CarWidgetModel(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      ta: ta ?? this.ta,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    if (ta != null) 'ta': ta,
  };

  factory CarWidgetModel.fromJson(Map<String, dynamic> json) => CarWidgetModel(
    id: json['id'] as String,
    x: (json['x'] as num).toInt(),
    y: (json['y'] as num).toInt(),
    w: (json['w'] as num).toInt(),
    h: (json['h'] as num).toInt(),
    ta: json['ta'] as String?,
  );
}

class CarLayoutModel {
  int v;
  double textScale;
  String clockFont;
  List<CarWidgetModel> widgets;

  CarLayoutModel({
    this.v = 2,
    this.textScale = 1.0,
    this.clockFont = 'thin',
    required this.widgets,
  });

  static CarLayoutModel get defaults => CarLayoutModel(
    v: 2,
    textScale: 1.0,
    clockFont: 'thin',
    widgets: [
      CarWidgetModel(id: 'clock', x: 1, y: 1, w: 6, h: 4),
      CarWidgetModel(id: 'prayer', x: 7, y: 1, w: 3, h: 2),
      CarWidgetModel(id: 'weather', x: 10, y: 1, w: 3, h: 2),
      CarWidgetModel(id: 'sports', x: 7, y: 3, w: 6, h: 2),
      CarWidgetModel(id: 'music', x: 1, y: 5, w: 8, h: 2),
      CarWidgetModel(id: 'speed', x: 9, y: 5, w: 2, h: 2, ta: 'center'),
      CarWidgetModel(id: 'shortcuts', x: 11, y: 5, w: 2, h: 2, ta: 'center'),
      CarWidgetModel(id: 'fuel', x: 1, y: 7, w: 6, h: 2),
    ],
  );

  Map<String, dynamic> toJson() => {
    'v': v,
    'textScale': textScale,
    'clockFont': clockFont,
    'widgets': widgets.map((w) => w.toJson()).toList(),
  };

  String toJsonString() => json.encode(toJson());

  factory CarLayoutModel.fromJson(Map<String, dynamic> json) {
    final rawWidgets = json['widgets'] as List<dynamic>? ?? [];
    return CarLayoutModel(
      v: (json['v'] as num?)?.toInt() ?? 2,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      clockFont: json['clockFont'] as String? ?? 'thin',
      widgets: rawWidgets.map((w) => CarWidgetModel.fromJson(w as Map<String, dynamic>)).toList(),
    );
  }

  factory CarLayoutModel.fromJsonString(String jsonStr) {
    return CarLayoutModel.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
  }
}
