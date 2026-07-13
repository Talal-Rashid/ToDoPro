import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import 'settings_screen.dart';
import 'package:intl/intl.dart';

import '../widgets/task_utils.dart';
import 'task_filter_sheet.dart';
import 'task_detail_screen.dart';
import 'task_create_sheet.dart';

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

  List<String> selectedFilterCategories = [];
  List<String> selectedFilterSubcategories = [];
  List<String> selectedFilterUrgencies = [];

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
    final now = DateTime.now();

    final filtered = allTasks.where((t) {
      final matchesSearch =
          t.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (selectedFilterCategories.isNotEmpty &&
          !selectedFilterCategories.contains(t.category)) {
        return false;
      }

      if (selectedFilterSubcategories.isNotEmpty) {
        String taskSub = t.subcategory.isEmpty ? 'None' : t.subcategory;
        if (!selectedFilterSubcategories.contains(taskSub)) {
          return false;
        }
      }

      if (selectedFilterUrgencies.isNotEmpty &&
          !selectedFilterUrgencies.contains(t.urgency)) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      String resolveActiveUrgencyTrack(Task task) {
        if (task.deadline == null) return task.urgency;
        final targetDate = DateTime.parse(task.deadline!);
        final difference = targetDate.difference(now);
        if (difference.isNegative) return task.urgency;

        if (difference.inHours <= 6) return '⏰ Within 6 Hours';
        if (difference.inHours <= 12) return '⏰ Within 12 Hours';
        if (difference.inHours <= 24) return '⏰ Within 24 Hours';
        if (difference.inDays <= 7) return '⏰ Within 1 Week';
        if (difference.inDays <= 30) return '⏰ Within 1 Month';
        return task.urgency;
      }

      final trackA = resolveActiveUrgencyTrack(a);
      final trackB = resolveActiveUrgencyTrack(b);
      final weightA = _getWeight(trackA);
      final weightB = _getWeight(trackB);

      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }
      if (a.deadline != null && b.deadline != null) {
        return DateTime.parse(
          a.deadline!,
        ).compareTo(DateTime.parse(b.deadline!));
      }
      return 0;
    });

    for (var task in filtered) {
      String key = task.urgency;
      if (groupMode == 'Urgency') {
        if (task.deadline != null) {
          final targetDate = DateTime.parse(task.deadline!);
          final diff = targetDate.difference(now);
          if (!diff.isNegative) {
            if (diff.inHours <= 6) {
              key = '⏰ Within 6 Hours';
            } else if (diff.inHours <= 12) {
              key = '⏰ Within 12 Hours';
            } else if (diff.inHours <= 24) {
              key = '⏰ Within 24 Hours';
            } else if (diff.inDays <= 7) {
              key = '⏰ Within 1 Week';
            } else if (diff.inDays <= 30) {
              key = '⏰ Within 1 Month';
            }
          }
        }
      } else {
        key = task.category;
      }

      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(task);
    }
    return grouped;
  }

  void _showFilterModalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0C0C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => TaskFilterSheet(
        selectedFilterCategories: selectedFilterCategories,
        selectedFilterSubcategories: selectedFilterSubcategories,
        selectedFilterUrgencies: selectedFilterUrgencies,
        onStateChanged: () {
          setState(() {});
        },
      ),
    );
  }

  void _showFocusedTaskOverlay(BuildContext context, Task task) {
    showFocusedTaskOverlay(context, task, _refresh);
  }

  void _showTaskBottomSheet(BuildContext context, Task? existingTask) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) => TaskCreateSheet(
        existingTask: existingTask,
        onRefresh: _refresh,
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final groupedTasks = _getGroupedTasks();
    final bool isFilteredActive =
        selectedFilterCategories.isNotEmpty ||
        selectedFilterSubcategories.isNotEmpty ||
        selectedFilterUrgencies.isNotEmpty;

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
          IconButton(
            icon: Icon(
              Icons.filter_alt,
              color: isFilteredActive ? Colors.amberAccent : Colors.white,
            ),
            tooltip: 'Filter Context Space',
            onPressed: () => _showFilterModalSheet(context),
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
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              _refresh();
            },
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: groupedTasks.entries.map((entry) {
                final groupKey = entry.key;
                final groupColor = groupMode == 'Urgency'
                    ? getUrgencyColor(groupKey)
                    : getDeterministicColor(groupKey);

                return Column(
                  key: ValueKey('group_$groupKey'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16.0,
                        top: 16.0,
                        bottom: 8.0,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 18,
                            decoration: BoxDecoration(
                              color: groupColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            groupKey.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
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
              decoration: buildFormInputDecoration('Task title'),
              onSubmitted: (v) async {
                final titleText = v.trim();
                if (titleText.isNotEmpty) {
                  task.title = titleText;
                  task.description = (_editingDescController?.text ?? '')
                      .trim();
                  await DBHelper.updateTask(task);

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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _editingDescController,
                    focusNode: _editingDescFocus,
                    decoration: buildFormInputDecoration(
                      'Notes / Description',
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

    final Color categoryColor = getDeterministicColor(task.category);
    final Color subcategoryColor = getDeterministicColor(task.subcategory);
    final Color urgencyColor = getUrgencyColor(task.urgency);
    final bool hasRepeatActive =
        task.isRepeating == 1 && task.repeatType != 'None';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.grey[900],
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: Container(color: categoryColor)),
                  Expanded(child: Container(color: subcategoryColor)),
                  Expanded(child: Container(color: urgencyColor)),
                ],
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _showFocusedTaskOverlay(context, task),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: task.isCompleted == 1,
                        onChanged: (v) {
                          task.isCompleted = v! ? 1 : 0;
                          DBHelper.updateTask(task).then((_) => _refresh());
                        },
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: task.isCompleted == 1
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "$metadata$dateInfo",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            if (task.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                task.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () =>
                                      _showTaskBottomSheet(context, task),
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Icon(
                                      Icons.edit_note,
                                      color: Colors.blueAccent,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                InkWell(
                                  onTap: () => _confirmDeletion(task),
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (task.syncToCalendar == 1 ||
                                task.setNotification == 1 ||
                                task.setAlarm == 1 ||
                                hasRepeatActive) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (task.syncToCalendar == 1)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.calendar_month,
                                        size: 14,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  if (task.setNotification == 1)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.notifications_active,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  if (task.setAlarm == 1)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.alarm,
                                        size: 14,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  if (hasRepeatActive)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Icon(
                                        Icons.loop,
                                        size: 14,
                                        color: Colors.purpleAccent,
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
                ),
              ),
            ),
          ],
        ),
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
}
