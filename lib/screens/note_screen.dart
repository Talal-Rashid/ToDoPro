import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../db_helper.dart';
import '../models.dart';
import '../widgets/drawing_canvas.dart';

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  List<Note> notes = [];
  @override
  void initState() { super.initState(); _refresh(); }
  
  Future<void> _refresh() async {
    var data = await DBHelper.getNotes();
    setState(() { notes = data; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notes")),
      body: GridView.builder(
        padding: EdgeInsets.all(10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10
        ),
        itemCount: notes.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) => NoteEditor(note: notes[i], onSave: _refresh)
          )),
          child: Card(
            color: Colors.grey[900],
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(notes[i].title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent), overflow: TextOverflow.ellipsis)),
                  IconButton(icon: Icon(Icons.delete, size: 16), onPressed: () => DBHelper.deleteNote(notes[i].id!).then((_) => _refresh())),
                ]),
                Divider(),
                Text(notes[i].content, maxLines: 4, overflow: TextOverflow.ellipsis),
                SizedBox(height: 6),
              ]),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'note_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => NoteEditor(onSave: _refresh)
        )),
        child: Icon(Icons.note_add),
      ),
    );
  }
}

class NoteEditor extends StatefulWidget {
  final Note? note;
  final VoidCallback onSave;
  const NoteEditor({super.key, this.note, required this.onSave});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late TextEditingController _title;
  late TextEditingController _content;
  String noteType = 'text';
  String? attachmentPath;
  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey<DrawingCanvasState>();
  DrawingCanvas? _canvas;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? "");
    _content = TextEditingController(text: widget.note?.content ?? "");
    noteType = widget.note?.noteType ?? 'text';
    attachmentPath = widget.note?.attachmentPath;
    _canvas = DrawingCanvas(canvasKey: _canvasKey, width: 800, height: 600);
    // If opening an existing canvas note, load its JSON into the canvas after build.
    if (attachmentPath != null && noteType == 'canvas' && attachmentPath!.endsWith('.canvas.json')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final f = File(attachmentPath!);
          if (await f.exists()) {
            final txt = await f.readAsString();
            await Future.delayed(Duration(milliseconds: 50));
            _canvasKey.currentState?.loadFromJson(txt);
            setState(() {});
          }
        } catch (e) {
          // ignore error loading canvas state
        }
      });
    }
  }

  void _insertBullet() {
    final text = _content.text;
    final sel = _content.selection;
    final int pos = sel.start >= 0 ? sel.start : text.length;
    final newText = text.replaceRange(pos, pos, '• ');
    _content.text = newText;
    _content.selection = TextSelection.collapsed(offset: pos + 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? "New Note" : "Edit Note"),
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: InputDecoration(labelText: "Title", border: OutlineInputBorder()),
          ),
          SizedBox(height: 20),
          Row(children: [
            Spacer(),
            IconButton(icon: Icon(Icons.format_list_bulleted), tooltip: 'Insert bullet', onPressed: _insertBullet),
          ]),
          SizedBox(height: 8),
          Row(children: [
            Text('Type: '),
            SizedBox(width: 12),
            DropdownButton<String>(
              value: noteType,
              items: [
                DropdownMenuItem(value: 'text', child: Text('Text')),
                DropdownMenuItem(value: 'canvas', child: Text('Canvas')),
                DropdownMenuItem(value: 'photo', child: Text('Photo')),
              ],
              onChanged: (v) => setState(() => noteType = v!),
            ),
          ]),
          SizedBox(height: 12),
          if (noteType == 'text')
            TextField(
              controller: _content,
              maxLines: 12,
              decoration: InputDecoration(labelText: "Content", border: OutlineInputBorder()),
            )
          else if (noteType == 'canvas') ...[
            // Controls
            Wrap(spacing: 8, runSpacing: 8, children: [
              DropdownButton<CanvasMode>(
                value: _canvasKey.currentState?.mode ?? CanvasMode.pen,
                items: CanvasMode.values.map((m) => DropdownMenuItem(value: m, child: Text(m.toString().split('.').last))).toList(),
                onChanged: (m) { if (m != null) { _canvasKey.currentState?.setMode(m); setState(() {}); } },
              ),
              IconButton(icon: Icon(Icons.format_color_text), tooltip: 'Stroke color', onPressed: () async { final c = await showDialog<Color?>(context: context, builder: (_) => _ColorPickerDialog(initial: _canvasKey.currentState?.strokeColor ?? Colors.black)); if (c != null) { _canvasKey.currentState?.setStrokeColor(c); setState(() {}); } }),
              IconButton(icon: Icon(Icons.format_color_fill), tooltip: 'Fill color', onPressed: () async { final c = await showDialog<Color?>(context: context, builder: (_) => _ColorPickerDialog(initial: _canvasKey.currentState?.fillColor ?? Colors.transparent)); if (c != null) { _canvasKey.currentState?.setFillColor(c); setState(() {}); } }),
              Row(children: [Text('Width'), SizedBox(width: 8), SizedBox(width: 120, child: Slider(value: _canvasKey.currentState?.strokeWidth ?? 4.0, min: 1, max: 20, onChanged: (v) { _canvasKey.currentState?.setStrokeWidth(v); setState(() {}); })),]),
              Row(children: [Text('Grid'), Switch(value: _canvasKey.currentState?.showGrid ?? false, onChanged: (v) { _canvasKey.currentState?.toggleGrid(v); setState(() {}); }), Text('Scale'), Switch(value: _canvasKey.currentState?.enableScale ?? false, onChanged: (v) { _canvasKey.currentState?.toggleScale(v); setState(() {}); })]),
              ElevatedButton(onPressed: () async { final c = await showDialog<Color?>(context: context, builder: (_) => _ColorPickerDialog(initial: Colors.white)); if (c != null) { _canvasKey.currentState?.fillBackground(c); setState(() {}); } }, child: Text('Fill Background')),
              ElevatedButton.icon(onPressed: () async {
                // Open fullscreen editor, pass current canvas JSON
                final currentJson = _canvasKey.currentState?.exportJson();
                final resultJson = await Navigator.push<String?>(context, MaterialPageRoute(builder: (_) => FullscreenCanvasEditor(initialJson: currentJson)));
                if (resultJson != null) {
                  final dir = await getApplicationDocumentsDirectory();
                  final file = File('${dir.path}/note_canvas_${DateTime.now().millisecondsSinceEpoch}.canvas.json');
                  await file.writeAsString(resultJson);
                  setState(() => attachmentPath = file.path);
                  // load back into embedded canvas
                  _canvasKey.currentState?.loadFromJson(resultJson);
                }
              }, icon: Icon(Icons.fullscreen), label: Text('Fullscreen')),
            ]),
            SizedBox(height: 8),
            // show saved image (photo/png) or editable canvas JSON. Otherwise show canvas for drawing
            Container(
              color: Colors.white,
              child: (() {
                if (attachmentPath == null) return _canvas;
                if (attachmentPath!.endsWith('.canvas.json')) return _canvas;
                // it's an image file - show image with Edit button
                return Column(children: [
                  Padding(padding: EdgeInsets.all(8), child: Image.file(File(attachmentPath!))),
                  TextButton(onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Edit Canvas?'),
                        content: Text('Editing will load an editable canvas if available. If an editable copy is not available you can start a new canvas (original image will remain as attachment).'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Edit')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        final orig = attachmentPath!;
                        final companion = orig.replaceAll(RegExp(r'\.[^.]+$'), '.canvas.json');
                        final cf = File(companion);
                        if (await cf.exists()) {
                          final txt = await cf.readAsString();
                          // set attachment to companion so editor shows canvas
                          setState(() => attachmentPath = companion);
                          // load strokes
                          await Future.delayed(Duration(milliseconds: 20));
                          _canvasKey.currentState?.loadFromJson(txt);
                        } else {
                          // create an empty companion editable JSON so the PNG can be edited (empty strokes)
                          final empty = jsonEncode({
                            'width': 800,
                            'height': 600,
                            'backgroundFill': Colors.white.toARGB32(),
                            'strokes': [],
                            'shapes': []
                          });
                          await cf.writeAsString(empty);
                          setState(() => attachmentPath = companion);
                          await Future.delayed(Duration(milliseconds: 20));
                          _canvasKey.currentState?.loadFromJson(empty);
                        }
                      } catch (e) {
                        setState(() => attachmentPath = null);
                      }
                    }
                  }, child: Text('Edit Canvas')),
                ]);
              })(),
            ),
            SizedBox(height: 8),
            Row(children: [
              ElevatedButton(onPressed: () => _canvasKey.currentState?.clear(), child: Text('Clear')),
              SizedBox(width: 12),
              ElevatedButton(onPressed: () async {
                final bytes = await _canvasKey.currentState?.exportPng();
                final jsonStr = _canvasKey.currentState?.exportJson();
                if (bytes != null) {
                  final dir = await getApplicationDocumentsDirectory();
                  final base = '${dir.path}/note_canvas_${DateTime.now().millisecondsSinceEpoch}';
                  final pngFile = File('$base.png');
                  await pngFile.writeAsBytes(bytes);
                  if (jsonStr != null) {
                    final jsonFile = File('$base.canvas.json');
                    await jsonFile.writeAsString(jsonStr);
                  }
                  setState(() => attachmentPath = pngFile.path);
                } else if (jsonStr != null) {
                  final dir = await getApplicationDocumentsDirectory();
                  final file = File('${dir.path}/note_canvas_${DateTime.now().millisecondsSinceEpoch}.canvas.json');
                  await file.writeAsString(jsonStr);
                  setState(() => attachmentPath = file.path);
                }
              }, child: Text('Save Canvas')),
            ])
          ] else if (noteType == 'photo') ...[
            if (attachmentPath != null) Padding(padding: EdgeInsets.only(bottom:8), child: Image.file(File(attachmentPath!))),
            Row(children: [
              ElevatedButton(onPressed: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (img != null) {
                  final dir = await getApplicationDocumentsDirectory();
                  final ext = img.path.contains('.') ? img.path.substring(img.path.lastIndexOf('.')) : '';
                  final file = await File(img.path).copy('${dir.path}/note_photo_${DateTime.now().millisecondsSinceEpoch}$ext');
                  setState(() => attachmentPath = file.path);
                }
              }, child: Text('Pick Photo')),
              SizedBox(width: 12),
              ElevatedButton(onPressed: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.camera);
                if (img != null) {
                  final dir = await getApplicationDocumentsDirectory();
                  final ext = img.path.contains('.') ? img.path.substring(img.path.lastIndexOf('.')) : '';
                  final file = await File(img.path).copy('${dir.path}/note_photo_${DateTime.now().millisecondsSinceEpoch}$ext');
                  setState(() => attachmentPath = file.path);
                }
              }, child: Text('Take Photo')),
            ])
          ],
          SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60)),
            onPressed: () async {
              if (_title.text.isEmpty) return;
              Note n = widget.note ?? Note(title: "", content: "");
              n.title = _title.text;
              n.content = _content.text;
              n.noteType = noteType;

              // if this is a canvas note and we have an active canvas, export editable JSON
              if (noteType == 'canvas' && _canvasKey.currentState != null) {
                try {
                  final jsonStr = _canvasKey.currentState?.exportJson();
                  if (jsonStr != null) {
                    final dir = await getApplicationDocumentsDirectory();
                    final file = File('${dir.path}/note_canvas_${DateTime.now().millisecondsSinceEpoch}.canvas.json');
                    await file.writeAsString(jsonStr);
                    attachmentPath = file.path;
                  }
                } catch (e) {
                  // ignore failures to export
                }
              }

              n.attachmentPath = attachmentPath;

              if (widget.note == null) {
                await DBHelper.insertNote(n);
              } else {
                await DBHelper.updateNote(n);
              }
              widget.onSave();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text("SAVE NOTE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});
  @override
  __ColorPickerDialogState createState() => __ColorPickerDialogState();
}

class __ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color selected;
  final List<Color> palette = [Colors.black, Colors.white, Colors.red, Colors.green, Colors.blue, Colors.yellow, Colors.orange, Colors.purple, Colors.brown, Colors.grey];
  @override
  void initState() { super.initState(); selected = widget.initial; }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pick color'),
      content: Wrap(spacing: 8, children: palette.map((c) => GestureDetector(
        onTap: () => setState(() => selected = c),
        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: c, border: selected == c ? Border.all(width: 3, color: Colors.black) : null)),
      )).toList()),
      actions: [TextButton(onPressed: () => Navigator.pop(context, null), child: Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, selected), child: Text('Select'))],
    );
  }
}

class FullscreenCanvasEditor extends StatefulWidget {
  final String? initialJson;
  const FullscreenCanvasEditor({super.key, this.initialJson});
  @override
  State<FullscreenCanvasEditor> createState() => _FullscreenCanvasEditorState();
}

class _FullscreenCanvasEditorState extends State<FullscreenCanvasEditor> {
  final GlobalKey<DrawingCanvasState> _fsKey = GlobalKey<DrawingCanvasState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialJson != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fsKey.currentState?.loadFromJson(widget.initialJson!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Canvas (Fullscreen)'),
        actions: [
          IconButton(icon: Icon(Icons.save), onPressed: () {
            final json = _fsKey.currentState?.exportJson();
            Navigator.pop(context, json);
          }),
        ],
      ),
      body: Center(child: SingleChildScrollView(child: DrawingCanvas(canvasKey: _fsKey, width: 1200, height: 900))),
    );
  }
}