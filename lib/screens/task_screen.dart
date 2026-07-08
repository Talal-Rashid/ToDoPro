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
  Map<String, int> urgencyWeights = {};
  String groupMode = 'Urgency';
  String searchQuery = "";
  bool isSearching = false;
  int? _editingTaskId;
  TextEditingController? _editingTitleController;
  TextEditingController? _editingDescController;
  FocusNode? _editingTitleFocus;
  FocusNode? _editingDescFocus;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    var data = await DBHelper.getTasks();
    var urgList = await DBHelper.getRawUrgencies();
    Map<String, int> weights = {};
    for (var u in urgList) {
      weights[u['name']] = u['weight'] ?? 99;
    }
    setState(() {
      allTasks = data;
      urgencyWeights = weights;
    });
  }

  int _getWeight(String urgency) {
    return urgencyWeights[urgency] ?? 99;
  }

  Map<String, List<Task>> _getGroupedTasks() {
    Map<String, List<Task>> grouped = {};
    final filtered = allTasks.where((t) {
      return t.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    filtered.sort(
      (a, b) => _getWeight(a.urgency).compareTo(_getWeight(b.urgency)),
    );

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
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search tasks...",
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => searchQuery = v),
              )
            : const Text("TodoPro Tasks"),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              isSearching = !isSearching;
              if (!isSearching) searchQuery = "";
            }),
          ),
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
            label: Text(groupMode),
            onPressed: () => setState(
              () => groupMode = groupMode == 'Urgency' ? 'Category' : 'Urgency',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings / Taxonomies',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const ManageTaxonomies()),
              );
              _refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_editingTaskId != null)
            Container(
              width: double.infinity,
              color: Colors.blueGrey[900],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text(
                'Inline Editor Active. Press Keyboard Enter to spawn next item.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: groupedTasks.entries.map((entry) {
                final groupKey = entry.key;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        groupKey.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ...entry.value.map((task) => _buildTaskTile(task)),
                    if (_editingTaskId == null)
                      ListTile(
                        leading: const Icon(
                          Icons.add_circle_outline,
                          color: Colors.green,
                        ),
                        title: const Text(
                          'Add new task...',
                          style: TextStyle(color: Colors.green),
                        ),
                        onTap: () async {
                          Task t = Task(
                            title: '',
                            category: groupMode == 'Urgency'
                                ? 'Study'
                                : groupKey,
                            urgency: groupMode == 'Urgency'
                                ? groupKey
                                : 'Today',
                          );
                          final id = await DBHelper.insertTask(t);
                          t.id = id;
                          await _refresh();
                          _startInlineEdit(t);
                        },
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'task_fab',
        onPressed: () => _showTaskBottomSheet(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskTile(Task task) {
    String metadata = groupMode == 'Urgency' ? task.category : task.urgency;
    if (task.subcategory.isNotEmpty) metadata += " / ${task.subcategory}";

    String dateInfo = "";
    if (task.deadline != null) {
      DateTime dt = DateTime.parse(task.deadline!);
      // Format context conditionally if time component exists or was bypassed
      if (task.deadline!.contains('T23:59:59') ||
          !task.deadline!.contains(':')) {
        dateInfo = " • ${DateFormat('MMM dd, yyyy').format(dt)}";
      } else {
        dateInfo = " • ${DateFormat('MMM dd, hh:mm a').format(dt)}";
      }
    }

    if (task.id != null && task.id == _editingTaskId) {
      _editingTitleController ??= TextEditingController(text: task.title);
      _editingDescController ??= TextEditingController(text: task.description);
      _editingTitleFocus ??= FocusNode();
      _editingDescFocus ??= FocusNode();

      return Container(
        key: _itemKeys.putIfAbsent(task.id!, () => GlobalKey()),
        color: Colors.grey[900],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            TextField(
              controller: _editingTitleController,
              focusNode: _editingTitleFocus,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Task title',
                border: InputBorder.none,
              ),
              onSubmitted: (v) async {
                final titleText = v.trim();
                if (titleText.isNotEmpty) {
                  task.title = titleText;
                  task.description = (_editingDescController?.text ?? '')
                      .trim();
                  await DBHelper.updateTask(task);

                  // Instantly chain spawn the next inline task template
                  Task newTask = Task(
                    title: '',
                    category: task.category,
                    subcategory: task.subcategory,
                    urgency: task.urgency,
                  );
                  final newId = await DBHelper.insertTask(newTask);
                  await _refresh();
                  setState(() {
                    _editingTaskId = newId;
                    _editingTitleController = TextEditingController(text: '');
                    _editingDescController = TextEditingController(text: '');
                    _editingTitleFocus = FocusNode();
                    _editingDescFocus = FocusNode();
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _editingTitleFocus?.requestFocus();
                  });
                }
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _editingDescController,
                    focusNode: _editingDescFocus,
                    decoration: const InputDecoration(
                      hintText: 'Notes / Description',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () async {
                    final titleText = (_editingTitleController?.text ?? '')
                        .trim();
                    if (titleText.isEmpty) {
                      await DBHelper.deleteTask(task.id!);
                    } else {
                      task.title = titleText;
                      task.description = (_editingDescController?.text ?? '')
                          .trim();
                      await DBHelper.updateTask(task);
                    }
                    _closeInlineEditor();
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.grey[900],
      child: ExpansionTile(
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted == 1
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Text(
          "$metadata$dateInfo",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        leading: Checkbox(
          value: task.isCompleted == 1,
          onChanged: (v) {
            task.isCompleted = v! ? 1 : 0;
            DBHelper.updateTask(task).then((_) => _refresh());
          },
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _showTaskBottomSheet(context, task),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(Icons.edit_note, color: Colors.blueAccent, size: 20),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _confirmDeletion(task),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  ),
                ),
              ],
            ),
            if (task.syncToCalendar == 1 ||
                task.setNotification == 1 ||
                task.setAlarm == 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (task.syncToCalendar == 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.calendar_month,
                          size: 14,
                          color: Colors.blueAccent,
                        ),
                      ),
                    if (task.setNotification == 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.notifications_active,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ),
                    if (task.setAlarm == 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.alarm,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        children: [
          if (task.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  task.description,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _closeInlineEditor() {
    setState(() {
      _editingTaskId = null;
      _editingTitleController = null;
      _editingDescController = null;
      _editingTitleFocus = null;
      _editingDescFocus = null;
    });
    _refresh();
  }

  void _startInlineEdit(Task task) {
    if (task.id == null) return;
    setState(() {
      _editingTaskId = task.id;
      _editingTitleController = TextEditingController(text: task.title);
      _editingDescController = TextEditingController(text: task.description);
      _editingTitleFocus = FocusNode();
      _editingDescFocus = FocusNode();
    });
  }

  void _confirmDeletion(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && task.id != null) {
      await DBHelper.deleteTask(task.id!);
      _refresh();
    }
  }

  void _showTaskBottomSheet(BuildContext context, Task? existingTask) async {
    final titleCtrl = TextEditingController(text: existingTask?.title ?? "");
    final descCtrl = TextEditingController(
      text: existingTask?.description ?? "",
    );

    String selectedCat = existingTask?.category ?? 'Study';
    String selectedSubCat = existingTask?.subcategory ?? 'None';
    if (selectedSubCat.isEmpty) selectedSubCat = 'None';
    String selectedUrg = existingTask?.urgency ?? 'Today';
    String selectedRepeat = existingTask?.repeatType ?? 'None';

    DateTime? deadlineDate;
    TimeOfDay? deadlineTime;

    if (existingTask?.deadline != null) {
      DateTime parsed = DateTime.parse(existingTask!.deadline!);
      deadlineDate = DateTime(parsed.year, parsed.month, parsed.day);
      if (!existingTask.deadline!.contains('T23:59:59')) {
        deadlineTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
    }

    bool isRepeating = existingTask?.isRepeating == 1;
    bool syncCal = existingTask?.syncToCalendar == 1;
    bool setNotify = existingTask?.setNotification == 1;
    bool setAlarm = existingTask?.setAlarm == 1;

    List<String> categories = await DBHelper.getCategories();
    List<String> urgencies = await DBHelper.getUrgencies();
    List<String> subcategories = await DBHelper.getSubcategories(selectedCat);

    if (!categories.contains(selectedCat) && selectedCat.isNotEmpty) {
      categories.add(selectedCat);
    }
    if (!urgencies.contains(selectedUrg) && selectedUrg.isNotEmpty) {
      urgencies.add(selectedUrg);
    }
    categories.add("+ Add New Category");
    urgencies.add("+ Add New Urgency");

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[950],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isTitleValid = titleCtrl.text.trim().isNotEmpty;

            List<String> buildDynamicSubCats() {
              List<String> items = [
                'None',
                ...subcategories.where(
                  (s) => s != 'None' && s != '+ Add New Subcategory',
                ),
              ];
              if (!items.contains(selectedSubCat)) {
                items.insert(1, selectedSubCat);
              }
              items.add("+ Add New Subcategory");
              return items;
            }

            void insertBullet() {
              final text = descCtrl.text;
              final sel = descCtrl.selection;
              final int pos = sel.start >= 0 ? sel.start : text.length;
              descCtrl.text = text.replaceRange(pos, pos, '• ');
              descCtrl.selection = TextSelection.collapsed(offset: pos + 2);
            }

            Future<void> handleCustomTaxonomy(
              String type,
              String currentVal,
            ) async {
              final textCtrl = TextEditingController();
              final added = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Add New $type'),
                  content: TextField(
                    controller: textCtrl,
                    autofocus: true,
                    decoration: InputDecoration(hintText: '$type name'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
              if (added != null && added.isNotEmpty) {
                if (type == 'Category') {
                  await DBHelper.insertCategory(added);
                  var updated = await DBHelper.getCategories();
                  var fetchedSubs = await DBHelper.getSubcategories(added);
                  setModalState(() {
                    categories = updated..add("+ Add New Category");
                    selectedCat = added;
                    selectedSubCat = 'None';
                    subcategories = fetchedSubs;
                  });
                } else if (type == 'Urgency') {
                  await DBHelper.insertUrgency(added, urgencies.length);
                  var updated = await DBHelper.getUrgencies();
                  setModalState(() {
                    urgencies = updated..add("+ Add New Urgency");
                    selectedUrg = added;
                  });
                } else if (type == 'Subcategory') {
                  await DBHelper.insertSubcategory(selectedCat, added);
                  var updated = await DBHelper.getSubcategories(selectedCat);
                  setModalState(() {
                    subcategories = updated;
                    selectedSubCat = added;
                  });
                }
              } else {
                setModalState(() {
                  if (type == 'Category') {
                    selectedCat = currentVal;
                  } else if (type == 'Urgency') {
                    selectedUrg = currentVal;
                  } else {
                    selectedSubCat = currentVal;
                  }
                });
              }
            }

            final visibleSubCats = buildDynamicSubCats();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        existingTask == null ? "New Task" : "Edit Task",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: "Title *",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (text) => setModalState(
                        () => isTitleValid = text.trim().isNotEmpty,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCat,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: "Category",
                              border: OutlineInputBorder(),
                            ),
                            items: categories
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: e.startsWith('+')
                                            ? Colors.green
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) async {
                              if (v == "+ Add New Category") {
                                handleCustomTaxonomy('Category', selectedCat);
                              } else {
                                var fetchedSubs =
                                    await DBHelper.getSubcategories(v!);
                                setModalState(() {
                                  selectedCat = v;
                                  selectedSubCat = 'None';
                                  subcategories = fetchedSubs;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedUrg,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: "Urgency",
                              border: OutlineInputBorder(),
                            ),
                            items: urgencies
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: e.startsWith('+')
                                            ? Colors.green
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == "+ Add New Urgency") {
                                handleCustomTaxonomy('Urgency', selectedUrg);
                              } else {
                                setModalState(() => selectedUrg = v!);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: visibleSubCats.contains(selectedSubCat)
                          ? selectedSubCat
                          : 'None',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Subcategory (Optional)",
                        border: OutlineInputBorder(),
                      ),
                      items: visibleSubCats
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                e,
                                style: TextStyle(
                                  color: e.startsWith('+')
                                      ? Colors.green
                                      : Colors.white,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == "+ Add New Subcategory") {
                          handleCustomTaxonomy('Subcategory', selectedSubCat);
                        } else {
                          setModalState(() => selectedSubCat = v!);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      minLines: 1,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        labelText: "Description",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.format_list_bulleted),
                          onPressed: insertBullet,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // SPLIT OPTIONAL DEADLINE MANAGEMENT VIEW
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.blueAccent,
                      ),
                      title: Text(
                        deadlineDate == null
                            ? "Set Date Deadline"
                            : DateFormat('MMM dd, yyyy').format(deadlineDate!),
                      ),
                      trailing: deadlineDate != null
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => setModalState(() {
                                deadlineDate = null;
                                deadlineTime = null;
                              }),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        DateTime? datePicked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2035),
                        );
                        if (datePicked != null) {
                          setModalState(() {
                            deadlineDate = datePicked;
                          });
                        }
                      },
                    ),
                    if (deadlineDate != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.access_time,
                          color: Colors.amber,
                        ),
                        title: Text(
                          deadlineTime == null
                              ? "Add Precise Time (Optional)"
                              : deadlineTime!.format(context),
                        ),
                        trailing: deadlineTime != null
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () =>
                                    setModalState(() => deadlineTime = null),
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () async {
                          TimeOfDay? timePicked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (timePicked != null) {
                            setModalState(() {
                              deadlineTime = timePicked;
                            });
                          }
                        },
                      ),
                    const Divider(),

                    // COMPACT REPEATING ROW IMPLEMENTATION
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Text(
                            'Repeating Task',
                            style: TextStyle(fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: isRepeating,
                            onChanged: (v) =>
                                setModalState(() => isRepeating = v),
                          ),
                          const Spacer(),
                          if (isRepeating)
                            SizedBox(
                              width: 140,
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedRepeat,
                                decoration: const InputDecoration(
                                  labelText: "Interval",
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                items:
                                    [
                                          'None',
                                          'Daily',
                                          'Weekly',
                                          'Biweekly',
                                          'Monthly',
                                        ]
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(
                                              e,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) =>
                                    setModalState(() => selectedRepeat = v!),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "Reminders & Integration",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ChoiceChip(
                          avatar: Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: syncCal ? Colors.white : Colors.blueAccent,
                          ),
                          label: const Text("Calendar"),
                          selected: syncCal,
                          selectedColor: Colors.blueAccent.withValues(
                            alpha: 0.3,
                          ),
                          onSelected: (v) => setModalState(() => syncCal = v),
                        ),
                        ChoiceChip(
                          avatar: Icon(
                            Icons.notifications_active,
                            size: 16,
                            color: setNotify ? Colors.white : Colors.amber,
                          ),
                          label: const Text("Notification"),
                          selected: setNotify,
                          selectedColor: Colors.amber.withValues(alpha: 0.3),
                          onSelected: (v) => setModalState(() => setNotify = v),
                        ),
                        ChoiceChip(
                          avatar: Icon(
                            Icons.alarm,
                            size: 16,
                            color: setAlarm ? Colors.white : Colors.redAccent,
                          ),
                          label: const Text("Alarm"),
                          selected: setAlarm,
                          selectedColor: Colors.redAccent.withValues(
                            alpha: 0.3,
                          ),
                          onSelected: (v) => setModalState(() => setAlarm = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!isTitleValid)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          "⚠️ A title is required to save this task.",
                          style: TextStyle(color: Colors.amber, fontSize: 13),
                        ),
                      ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: isTitleValid
                            ? Colors.blueAccent
                            : Colors.grey[800],
                      ),
                      onPressed: isTitleValid
                          ? () async {
                              final title = titleCtrl.text.trim();
                              Task t =
                                  existingTask ??
                                  Task(title: "", category: "", urgency: "");
                              t.title = title;
                              t.description = descCtrl.text.trim();
                              t.category = selectedCat;
                              t.subcategory = selectedSubCat == 'None'
                                  ? ''
                                  : selectedSubCat;
                              t.urgency = selectedUrg;

                              if (deadlineDate != null) {
                                if (deadlineTime != null) {
                                  t.deadline = DateTime(
                                    deadlineDate!.year,
                                    deadlineDate!.month,
                                    deadlineDate!.day,
                                    deadlineTime!.hour,
                                    deadlineTime!.minute,
                                  ).toIso8601String();
                                } else {
                                  // Assign absolute end of day block to indicate timeless date flag safely
                                  t.deadline = DateTime(
                                    deadlineDate!.year,
                                    deadlineDate!.month,
                                    deadlineDate!.day,
                                    23,
                                    59,
                                    59,
                                  ).toIso8601String();
                                }
                              } else {
                                t.deadline = null;
                              }

                              t.isRepeating = isRepeating ? 1 : 0;
                              t.repeatType = isRepeating
                                  ? selectedRepeat
                                  : 'None';
                              t.syncToCalendar = syncCal ? 1 : 0;
                              t.setNotification = setNotify ? 1 : 0;
                              t.setAlarm = setAlarm ? 1 : 0;

                              if (existingTask == null) {
                                await DBHelper.insertTask(t);
                              } else {
                                await DBHelper.updateTask(t);
                              }
                              _refresh();
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            }
                          : null,
                      child: Text(
                        "SAVE TASK",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isTitleValid ? Colors.white : Colors.white38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) => _refresh());
  }
}

class FilteredTasksScreen extends StatefulWidget {
  final String filterBy;
  final String value;
  const FilteredTasksScreen({
    super.key,
    required this.filterBy,
    required this.value,
  });
  @override
  State<FilteredTasksScreen> createState() => _FilteredTasksScreenState();
}

class _FilteredTasksScreenState extends State<FilteredTasksScreen> {
  List<Task> tasks = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DBHelper.getTasks();
    if (mounted) {
      setState(() {
        tasks = all
            .where(
              (t) => widget.filterBy == 'Category'
                  ? t.category == widget.value
                  : t.urgency == widget.value,
            )
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.value)),
      body: ListView(
        children: tasks
            .map(
              (t) => ListTile(
                title: Text(t.title.isEmpty ? '(no title)' : t.title),
                subtitle: Text(
                  t.description.isEmpty ? '(no details)' : t.description,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
