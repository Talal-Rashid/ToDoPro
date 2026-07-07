import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import 'manage_taxonomies.dart';
import 'package:intl/intl.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<Task> allTasks = [];
  String groupMode = 'Urgency'; 
  String searchQuery = "";
  bool isSearching = false;
  int? _editingTaskId;
  TextEditingController? _editingTitleController;
  TextEditingController? _editingDescController;
  FocusNode? _editingTitleFocus;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  final Map<int, bool> _expanded = {};

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    var data = await DBHelper.getTasks();
    setState(() { allTasks = data; });
  }
  


  // Sorting logic: Within categories, sort by Urgency
  int _urgencyWeight(String urgency) {
    switch (urgency) {
      case 'Today': return 0;
      case 'Urgent': return 1;
      case 'Not Urgent': return 2;
      case 'Long Term': return 3;
      default: return 4;
    }
  }

  Map<String, List<Task>> _getGroupedTasks() {
    Map<String, List<Task>> grouped = {};
    
    final filtered = allTasks.where((t) {
      return t.title.toLowerCase().contains(searchQuery.toLowerCase()) || 
             t.description.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    // Secondary sorting by Urgency within the groups
    filtered.sort((a, b) => _urgencyWeight(a.urgency).compareTo(_urgencyWeight(b.urgency)));

    for (var task in filtered) {
      String key = groupMode == 'Urgency' ? task.urgency : task.category;
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(task);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedTasks = _getGroupedTasks();
    return Scaffold(
      appBar: AppBar(
        title: isSearching 
          ? TextField(
              autofocus: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(hintText: "Search tasks...", border: InputBorder.none),
              onChanged: (v) => setState(() => searchQuery = v),
            )
          : Text("Tasks"),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              isSearching = !isSearching;
              if (!isSearching) searchQuery = "";
            }),
          ),
          TextButton.icon(
            icon: Icon(Icons.swap_horiz, color: Colors.blueAccent),
            label: Text(groupMode),
            onPressed: () => setState(() => groupMode = groupMode == 'Urgency' ? 'Category' : 'Urgency'),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            tooltip: 'Manage categories & urgencies',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (c) => ManageTaxonomies()));
              _refresh();
            },
          )
        ],
      ),
      body: Column(
        children: [
          if (_editingTaskId != null)
            Container(
              width: double.infinity,
              color: Colors.yellow[50],
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text('Inline mode: press Enter to add another. Leave title empty and press ✓ to remove.'),
            ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: groupedTasks.entries.map((entry) {
                // compute default category/urgency for new tasks inside this group
                final groupKey = entry.key;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: GestureDetector(
                        onTap: () {
                          // navigate to filtered list for this group
                          Navigator.push(context, MaterialPageRoute(builder: (_) => FilteredTasksScreen(filterBy: groupMode == 'Urgency' ? 'Urgency' : 'Category', value: groupKey)));
                        },
                        child: Text(groupKey.toUpperCase(), style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                    ),
                    ...entry.value.map((task) => _buildTaskTile(task)),
                    // blank add-new tile at end for quick inline creation
                    if (_editingTaskId == null)
                      ListTile(
                        leading: Icon(Icons.add_circle_outline, color: Colors.green),
                        title: Text('Add new', style: TextStyle(color: Colors.green)),
                        onTap: () async {
                          // create a new blank task prefilled with this group's category/urgency
                          Task t = Task(title: '', category: groupMode == 'Urgency' ? '' : groupKey, urgency: groupMode == 'Urgency' ? groupKey : '');
                          final id = await DBHelper.insertTask(t);
                          t.id = id;
                          await _refresh();
                          // start inline editing of the newly created task
                          _startInlineEdit(t);
                        },
                      )
                    else
                      // when already editing, show the inline editor for that task (rendered in _buildTaskTile)
                      SizedBox.shrink(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'task_fab',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskEditor(onSave: _refresh))),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskTile(Task task) {
    // Determine what metadata to show based on the view mode
    String metadata = groupMode == 'Urgency' ? task.category : task.urgency;
    String dateInfo = task.deadline != null ? " • ${DateFormat('MMM dd').format(DateTime.parse(task.deadline!))}" : "";

    // if this task is currently being edited inline, render inline edit fields
    if (task.id != null && task.id == _editingTaskId) {
      _editingTitleController ??= TextEditingController(text: task.title);
      _editingDescController ??= TextEditingController(text: task.description);
      _editingTitleFocus ??= FocusNode();
      // attach focus listener to delete if left empty when focus lost
      _editingTitleFocus!.removeListener(_onEditingFocusChange);
      _editingTitleFocus!.addListener(_onEditingFocusChange);
      return Container(
        key: _itemKeys.putIfAbsent(task.id!, () => GlobalKey()),
        child: ListTile(
          title: TextField(
            controller: _editingTitleController,
            focusNode: _editingTitleFocus,
            autofocus: true,
            decoration: InputDecoration(hintText: 'Task title', border: InputBorder.none),
            onSubmitted: (v) async {
              task.title = v;
              await DBHelper.updateTask(task);
              // create another blank task in same group and start editing it
              final newTask = Task(title: '', category: task.category, urgency: task.urgency);
              final newId = await DBHelper.insertTask(newTask);
              await _refresh();
              // switch editing to new task
              setState(() {
                _editingTaskId = newId;
                _editingTitleController = TextEditingController(text: '');
                _editingDescController = TextEditingController(text: '');
                _editingTitleFocus = FocusNode();
              });
              // scroll and focus the new editor
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final key = _itemKeys[newId];
                if (key?.currentContext != null) Scrollable.ensureVisible(key!.currentContext!, duration: Duration(milliseconds: 200));
                _editingTitleFocus?.requestFocus();
              });
            },
          ),
          subtitle: TextField(
            controller: _editingDescController,
            decoration: InputDecoration(hintText: 'Notes (optional)', border: InputBorder.none),
            maxLines: 2,
            onSubmitted: (v) async {
              task.description = v;
              await DBHelper.updateTask(task);
            },
          ),
          trailing: IconButton(icon: Icon(Icons.check), onPressed: () async {
            final titleText = (_editingTitleController?.text ?? '').trim();
            final descText = (_editingDescController?.text ?? '').trim();
            if (titleText.isEmpty) {
              // delete the placeholder task
              if (task.id != null) await DBHelper.deleteTask(task.id!);
            } else {
              task.title = titleText;
              task.description = descText;
              await DBHelper.updateTask(task);
            }
            setState(() { _editingTaskId = null; _editingTitleController = null; _editingDescController = null; _editingTitleFocus = null; });
          }),
        ),
      );
    }

    // Use a custom ListTile + expandable panel so subtitle taps won't be swallowed by ExpansionTile
    final expanded = task.id != null && (_expanded[task.id!] ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          onTap: () { if (task.id != null) _startInlineEdit(task); },
          leading: Checkbox(
            value: task.isCompleted == 1,
            onChanged: (v) {
              task.isCompleted = v! ? 1 : 0;
              DBHelper.updateTask(task).then((_) => _refresh());
            },
          ),
          title: Text(task.title, style: TextStyle(decoration: task.isCompleted == 1 ? TextDecoration.lineThrough : null)),
          subtitle: InkWell(
            onTap: () { if (task.id != null) _startInlineEdit(task); },
            child: Text("$metadata$dateInfo", style: TextStyle(color: Colors.grey)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete task?'),
                      content: Text('This will permanently delete the task.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete')),
                      ],
                    ),
                  );
                  if (confirmed == true && task.id != null) {
                    await DBHelper.deleteTask(task.id!);
                    _refresh();
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.edit_note, color: Colors.grey),
                onPressed: () async {
                  if (task.id != null) {
                    _startInlineEdit(task);
                  } else {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => TaskEditor(task: task, onSave: _refresh)));
                  }
                },
              ),
              IconButton(
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() { if (task.id != null) _expanded[task.id!] = !(_expanded[task.id!] ?? false); }),
              ),
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: EdgeInsets.fromLTRB(72, 0, 16, 16),
            child: GestureDetector(
              onTap: () { if (task.id != null) _startInlineEdit(task); },
              child: Align(alignment: Alignment.centerLeft, child: Row(children: [Expanded(child: Text(task.description.isEmpty ? "No details." : task.description)), SizedBox(width: 8), Icon(Icons.edit, size: 18, color: Colors.grey)])),
            ),
          ),
      ],
    );
  }

  void _startInlineEdit(Task task) {
    if (task.id == null) return;
    debugPrint('START_INLINE_EDIT: ${task.id}');
    _editingTaskId = task.id;
    _editingTitleController = TextEditingController(text: task.title);
    _editingDescController = TextEditingController(text: task.description);
    _editingTitleFocus = FocusNode();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) { _editingTitleFocus?.requestFocus(); });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Editing task ${task.id}'), duration: Duration(milliseconds: 900)));
  }

  void _onEditingFocusChange() async {
    if (_editingTitleFocus == null) return;
    if (!_editingTitleFocus!.hasFocus && _editingTaskId != null) {
      final currentText = (_editingTitleController?.text ?? '').trim();
      if (currentText.isEmpty) {
        // delete placeholder
        final id = _editingTaskId!;
        await DBHelper.deleteTask(id);
        await _refresh();
      }
      setState(() { _editingTaskId = null; _editingTitleController = null; _editingDescController = null; _editingTitleFocus = null; });
    }
  }
}

// --- FULL SCREEN EDITOR ---
class TaskEditor extends StatefulWidget {
  final Task? task;
  final VoidCallback onSave;
  final bool autofocusTitle;
  const TaskEditor({super.key, this.task, required this.onSave, this.autofocusTitle = false});

  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late TextEditingController _title;
  late TextEditingController _desc;
  late String cat;
  late String urg;
  DateTime? selectedDate;
  int isRepeating = 0;
  late String repeatType;
  List<String> cats = [];
  List<String> urgList = [];

  void _insertBullet() {
    final text = _desc.text;
    final sel = _desc.selection;
    final int pos = sel.start >= 0 ? sel.start : text.length;
    final newText = text.replaceRange(pos, pos, '• ');
    _desc.text = newText;
    _desc.selection = TextSelection.collapsed(offset: pos + 2);
  }

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? "");
    _desc = TextEditingController(text: widget.task?.description ?? "");
    cat = widget.task?.category ?? 'Study';
    urg = widget.task?.urgency ?? 'Today';
    if (widget.task?.deadline != null) selectedDate = DateTime.parse(widget.task!.deadline!);
    isRepeating = widget.task?.isRepeating ?? 0;
    repeatType = widget.task?.repeatType ?? 'None';
    _loadTaxonomies();
  }

  Future<void> _loadTaxonomies() async {
    cats = await DBHelper.getCategories();
    urgList = await DBHelper.getUrgencies();
    // ensure current values exist in lists
    if (!cats.contains(cat) && cat.isNotEmpty) cats.insert(0, cat);
    if (!urgList.contains(urg) && urg.isNotEmpty) urgList.insert(0, urg);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.task == null ? "New Task" : "Edit Task")),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          TextField(controller: _title, autofocus: widget.autofocusTitle, decoration: InputDecoration(labelText: "Title", border: OutlineInputBorder())),
          SizedBox(height: 20),
          Row(children: [
            Spacer(),
            IconButton(icon: Icon(Icons.format_list_bulleted), tooltip: 'Insert bullet', onPressed: _insertBullet),
          ]),
          TextField(controller: _desc, maxLines: 5, decoration: InputDecoration(labelText: "Mental Clutter / Description", border: OutlineInputBorder())),
          SizedBox(height: 20),
          ListTile(
            title: Text("Deadline: ${selectedDate == null ? 'None' : DateFormat('MMM dd, yyyy').format(selectedDate!)}"),
            trailing: Icon(Icons.calendar_today),
            onTap: () async {
              DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (picked != null) setState(() => selectedDate = picked);
            },
          ),
          Divider(),
          DropdownButtonFormField<String>(
            initialValue: cats.contains(cat) ? cat : (cats.isNotEmpty ? cats.first : null),
            decoration: InputDecoration(labelText: "Category"),
            items: cats.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => cat = v!),
          ),
          SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: urgList.contains(urg) ? urg : (urgList.isNotEmpty ? urgList.first : null),
            decoration: InputDecoration(labelText: "Urgency"),
            items: urgList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => urg = v!),
          ),
          SizedBox(height: 20),
          SwitchListTile(
            title: Text('Repeating'),
            value: isRepeating == 1,
            onChanged: (v) => setState(() => isRepeating = v ? 1 : 0),
          ),
          DropdownButtonFormField<String>(
            initialValue: repeatType,
            decoration: InputDecoration(labelText: "Repeat"),
            items: ['None', 'Daily', 'Weekly', 'Monthly'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: isRepeating == 1 ? (v) => setState(() => repeatType = v!) : null,
          ),
          SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 60)),
            onPressed: () async {
              Task t = widget.task ?? Task(title: "", category: "", urgency: "");
              t.title = _title.text;
              t.description = _desc.text;
              t.category = cat;
              t.urgency = urg;
              t.deadline = selectedDate?.toIso8601String();
              t.isRepeating = isRepeating;
              t.repeatType = repeatType;

              if (widget.task == null) {
                await DBHelper.insertTask(t);
              } else {
                await DBHelper.updateTask(t);
              }

              widget.onSave();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text("SAVE TASK", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

class FilteredTasksScreen extends StatefulWidget {
  final String filterBy; // 'Category' or 'Urgency'
  final String value;
  const FilteredTasksScreen({super.key, required this.filterBy, required this.value});
  @override
  State<FilteredTasksScreen> createState() => _FilteredTasksScreenState();
}

class _FilteredTasksScreenState extends State<FilteredTasksScreen> {
  List<Task> tasks = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final all = await DBHelper.getTasks();
    setState(() {
      tasks = all.where((t) => widget.filterBy == 'Category' ? t.category == widget.value : t.urgency == widget.value).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.value)),
      body: ListView(children: tasks.map((t) => ListTile(
        title: Text(t.title.isEmpty ? '(no title)' : t.title),
        subtitle: Text(t.description.isEmpty ? '(no details)' : t.description),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskEditor(task: t, onSave: _load))),
      )).toList()),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // create blank task in this filter
          final newTask = Task(title: '', category: widget.filterBy == 'Category' ? widget.value : '', urgency: widget.filterBy == 'Urgency' ? widget.value : '');
          final id = await DBHelper.insertTask(newTask);
          newTask.id = id;
          await _load();
          if (context.mounted) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => TaskEditor(task: newTask, onSave: _load, autofocusTitle: true)));
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}