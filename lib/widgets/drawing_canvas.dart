import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:convert';

enum CanvasMode { pen, line, rect, circle, triangle }

class DrawStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  DrawStroke(this.points, this.color, this.strokeWidth);
}

class DrawShape {
  final CanvasMode mode;
  final Offset start;
  final Offset end;
  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  DrawShape({required this.mode, required this.start, required this.end, required this.strokeColor, this.fillColor, required this.strokeWidth});
}

class DrawingCanvas extends StatefulWidget {
  final double width;
  final double height;
  final Color backgroundColor;
  final GlobalKey<DrawingCanvasState>? canvasKey;

  const DrawingCanvas({this.canvasKey, this.width = 800, this.height = 600, this.backgroundColor = Colors.white}) : super(key: canvasKey);

  @override
  DrawingCanvasState createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  List<DrawStroke> strokes = [];
  List<DrawShape> shapes = [];
  Color strokeColor = Colors.black;
  Color? fillColor;
  double strokeWidth = 4.0;
  CanvasMode mode = CanvasMode.pen;
  bool showGrid = false;
  bool enableScale = false;
  double scale = 1.0;
  Color backgroundFill = Colors.white;

  // active points for pen
  List<Offset> _currentPoints = [];
  // active shape start
  Offset? _shapeStart;

  void clear() { setState(() { strokes.clear(); shapes.clear(); _currentPoints.clear(); }); }

  void setMode(CanvasMode m) => setState(() => mode = m);
  void setStrokeColor(Color c) => setState(() => strokeColor = c);
  void setFillColor(Color? c) => setState(() => fillColor = c);
  void setStrokeWidth(double w) => setState(() => strokeWidth = w);
  void toggleGrid(bool v) => setState(() => showGrid = v);
  void toggleScale(bool v) => setState(() => enableScale = v);
  void setScale(double s) => setState(() => scale = s);
  void fillBackground(Color c) => setState(() => backgroundFill = c);

  Future<Uint8List?> exportPng() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(widget.width, widget.height);
    // paint background
    final bgPaint = Paint()..color = backgroundFill;
    canvas.drawRect(Offset.zero & size, bgPaint);
    final painter = _DrawingPainter(strokes: strokes, shapes: shapes, strokeWidth: strokeWidth, showGrid: false, strokeColor: strokeColor, fillColor: fillColor);
    painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  /// Export canvas data (strokes + shapes + metadata) as a JSON string.
  String exportJson() {
    final Map<String, dynamic> data = {
      'width': widget.width,
      'height': widget.height,
      'backgroundFill': backgroundFill.toARGB32(),
      'strokes': strokes.map((s) => {
            'points': s.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
            'color': s.color.toARGB32(),
            'strokeWidth': s.strokeWidth,
          }).toList(),
      'shapes': shapes.map((s) => {
            'mode': s.mode.toString(),
            'start': {'x': s.start.dx, 'y': s.start.dy},
            'end': {'x': s.end.dx, 'y': s.end.dy},
            'strokeColor': s.strokeColor.toARGB32(),
            'fillColor': s.fillColor?.toARGB32(),
            'strokeWidth': s.strokeWidth,
          }).toList(),
    };
    return jsonEncode(data);
  }

  /// Load the canvas state from a previously exported JSON string.
  void loadFromJson(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final List<dynamic> sdata = data['strokes'] ?? [];
    final List<dynamic> shdata = data['shapes'] ?? [];
    final List<DrawStroke> newStrokes = [];
    final List<DrawShape> newShapes = [];
    for (var si in sdata) {
      final pts = <Offset>[];
      for (var p in si['points']) {
        pts.add(Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()));
      }
      newStrokes.add(DrawStroke(pts, Color(si['color']), (si['strokeWidth'] as num).toDouble()));
    }
    for (var sh in shdata) {
      final modeStr = sh['mode'] as String;
      CanvasMode mode = CanvasMode.pen;
      for (var m in CanvasMode.values) {
        if (m.toString() == modeStr) {
          mode = m;
        }
      }
      final start = Offset((sh['start']['x'] as num).toDouble(), (sh['start']['y'] as num).toDouble());
      final end = Offset((sh['end']['x'] as num).toDouble(), (sh['end']['y'] as num).toDouble());
      final strokeColor = Color(sh['strokeColor']);
      final fillColor = sh['fillColor'] != null ? Color(sh['fillColor']) : null;
      final strokeW = (sh['strokeWidth'] as num).toDouble();
      newShapes.add(DrawShape(mode: mode, start: start, end: end, strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeW));
    }
    setState(() {
      strokes = newStrokes;
      shapes = newShapes;
      final bgVal = (data['backgroundFill'] as num?)?.toInt() ?? Colors.white.toARGB32();
      backgroundFill = Color(bgVal);
    });
  }

  @override
  Widget build(BuildContext context) {
    // When scaled we adjust input coordinates and visually scale the paint area.
    Widget paintArea = GestureDetector(
      onPanStart: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        var local = box.globalToLocal(details.globalPosition);
        local = Offset(local.dx / scale, local.dy / scale);
        // clamp to canvas bounds
        local = Offset(local.dx.clamp(0.0, widget.width), local.dy.clamp(0.0, widget.height));
        if (mode == CanvasMode.pen) {
          _currentPoints = [local];
        } else {
          _shapeStart = local;
        }
        setState(() {});
      },
      onPanUpdate: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        var local = box.globalToLocal(details.globalPosition);
        local = Offset(local.dx / scale, local.dy / scale);
        // clamp to canvas bounds
        local = Offset(local.dx.clamp(0.0, widget.width), local.dy.clamp(0.0, widget.height));
        if (mode == CanvasMode.pen) {
          _currentPoints.add(local);
        } else if (_shapeStart != null) {
          if (_currentPoints.isEmpty) {
            _currentPoints.add(local);
          } else {
            _currentPoints[_currentPoints.length - 1] = local;
          }
        }
        setState(() {});
      },
      onPanEnd: (details) {
        if (mode == CanvasMode.pen) {
          if (_currentPoints.isNotEmpty) {
            strokes.add(DrawStroke(List.of(_currentPoints), strokeColor, strokeWidth));
            _currentPoints.clear();
          }
        } else if (_shapeStart != null) {
          final end = _currentPoints.isNotEmpty ? _currentPoints.last : _shapeStart!;
          shapes.add(DrawShape(mode: mode, start: _shapeStart!, end: end, strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth));
          _currentPoints.clear();
        }
        _shapeStart = null;
        setState(() {});
      },
      child: CustomPaint(
        size: Size(widget.width, widget.height),
        painter: _DrawingPainter(strokes: strokes, shapes: shapes, currentPoints: _currentPoints.isNotEmpty ? _currentPoints : null, currentShapeStart: _shapeStart, currentShapeEnd: _currentPoints.isNotEmpty ? _currentPoints.last : null, strokeColor: strokeColor, fillColor: fillColor, strokeWidth: strokeWidth, showGrid: showGrid),
      ),
    );

    Widget childWidget = Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      child: paintArea,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (enableScale)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            child: Row(children: [Text('Scale'), SizedBox(width: 8), Expanded(child: Slider(value: scale, min: 0.2, max: 3.0, divisions: 28, onChanged: (v) => setScale(v))), Text(scale.toStringAsFixed(2))]),
          ),
        childWidget,
      ],
    );

    return Container(color: Colors.grey[300], child: content);
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  final List<DrawShape> shapes;
  final List<Offset>? currentPoints;
  final Offset? currentShapeStart;
  final Offset? currentShapeEnd;
  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  final bool showGrid;

  _DrawingPainter({this.strokes = const [], this.shapes = const [], this.currentPoints, this.currentShapeStart, this.currentShapeEnd, this.strokeColor = Colors.black, this.fillColor, this.strokeWidth = 4.0, this.showGrid = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      final gridPaint = Paint()..color = Colors.grey.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.5;
      const step = 20.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // draw saved shapes
    for (var s in shapes) {
      final paint = Paint()..color = s.strokeColor..style = PaintingStyle.stroke..strokeWidth = s.strokeWidth;
      final fill = Paint()..color = s.fillColor ?? Colors.transparent..style = PaintingStyle.fill;
      _drawShape(canvas, s.mode, s.start, s.end, paint, fill);
    }

    // draw saved strokes
    for (var st in strokes) {
      final paint = Paint()..color = st.color..strokeCap = StrokeCap.round..strokeWidth = st.strokeWidth..style = PaintingStyle.stroke;
      for (int i = 0; i < st.points.length - 1; i++) {
        canvas.drawLine(st.points[i], st.points[i + 1], paint);
      }
    }

    // draw current stroke
    if (currentPoints != null && currentPoints!.isNotEmpty) {
      final paint = Paint()..color = strokeColor..strokeCap = StrokeCap.round..strokeWidth = strokeWidth..style = PaintingStyle.stroke;
      for (int i = 0; i < currentPoints!.length - 1; i++) {
        canvas.drawLine(currentPoints![i], currentPoints![i + 1], paint);
      }
    }

    // draw current shape preview
    if (currentShapeStart != null && currentShapeEnd != null) {
      final paint = Paint()..color = strokeColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth;
      final fill = Paint()..color = fillColor ?? Colors.transparent..style = PaintingStyle.fill;
      _drawShape(canvas, CanvasMode.rect, currentShapeStart!, currentShapeEnd!, paint, fill);
    }
  }

  void _drawShape(Canvas canvas, CanvasMode mode, Offset a, Offset b, Paint stroke, Paint fill) {
    switch (mode) {
      case CanvasMode.line:
        canvas.drawLine(a, b, stroke);
        break;
      case CanvasMode.rect:
        final rect = Rect.fromPoints(a, b);
        if (fill.color != Colors.transparent) canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        break;
      case CanvasMode.circle:
        final center = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final radius = (b - a).distance / 2;
        if (fill.color != Colors.transparent) canvas.drawCircle(center, radius, fill);
        canvas.drawCircle(center, radius, stroke);
        break;
      case CanvasMode.triangle:
        final p1 = a;
        final p2 = Offset(b.dx, a.dy);
        final p3 = Offset((a.dx + b.dx) / 2, b.dy);
        final path = Path()..moveTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..lineTo(p3.dx, p3.dy)..close();
        if (fill.color != Colors.transparent) canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
        break;
      case CanvasMode.pen:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
