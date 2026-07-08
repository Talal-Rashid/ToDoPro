import 'package:flutter/material.dart';
import 'dart:ui'; // Required for ImageFilter backdrop blur
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

  List<String> selectedFilterCategories = [];
  List<String> selectedFilterSubcategories = [];
  List<String> selectedFilterUrgencies = [];

  final List<Color> _colorPalette = [
    Colors.blueAccent,
    Colors.indigoAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.amberAccent,
    Colors.greenAccent,
    Colors.deepPurpleAccent,
    Colors.cyanAccent,
    Colors.lightBlueAccent,
    Colors.orangeAccent,
    Colors.limeAccent,
    Colors.purpleAccent,
  ];

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

  Color _getDeterministicColor(String value) {
    if (value.isEmpty || value == 'None') return Colors.grey[700]!;
    int hash = 0;
    for (int i = 0; i < value.length; i++) {
      hash = value.codeUnitAt(i) + ((hash << 5) - hash);
    }
    int index = hash.abs() % _colorPalette.length;
    return _colorPalette[index];
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'today':
        return Colors.red;
      case 'urgent':
        return Colors.redAccent;
      case 'not urgent':
        return Colors.green;
      case 'long term':
        return Colors.blueGrey;
      default:
        return _getDeterministicColor(urgency);
    }
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

  void _showFilterModalSheet(BuildContext context) async {
    List<String> availCats = await DBHelper.getCategories();
    List<String> availUrgencies = await DBHelper.getUrgencies();

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0C0C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Refine Workspace",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              selectedFilterCategories.clear();
                              selectedFilterSubcategories.clear();
                              selectedFilterUrgencies.clear();
                            });
                            setState(() {});
                          },
                          child: const Text(
                            "Reset Filters",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),

                    ExpansionTile(
                      leading: const Icon(
                        Icons.category,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      title: Text(
                        selectedFilterCategories.isEmpty
                            ? "All Categories"
                            : "Categories (${selectedFilterCategories.length} selected)",
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: selectedFilterCategories.isNotEmpty
                          ? Text(
                              selectedFilterCategories.join(', '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      children: availCats.map((cat) {
                        final isSel = selectedFilterCategories.contains(cat);
                        return CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            cat,
                            style: const TextStyle(fontSize: 13),
                          ),
                          value: isSel,
                          onChanged: (bool? checked) {
                            setModalState(() {
                              if (checked == true) {
                                selectedFilterCategories.add(cat);
                              } else {
                                selectedFilterCategories.remove(cat);
                                selectedFilterSubcategories.clear();
                              }
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),

                    if (selectedFilterCategories.isNotEmpty)
                      FutureBuilder<Map<String, List<String>>>(
                        future: () async {
                          Map<String, List<String>> structure = {};
                          for (var cat in selectedFilterCategories) {
                            var subs = await DBHelper.getSubcategories(cat);
                            if (subs.isNotEmpty) structure[cat] = subs;
                          }
                          return structure;
                        }(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final structure = snapshot.data!;

                          return ExpansionTile(
                            leading: const Icon(
                              Icons.layers,
                              color: Colors.orangeAccent,
                              size: 20,
                            ),
                            title: Text(
                              selectedFilterSubcategories.isEmpty
                                  ? "All Subcategories under selections"
                                  : "Subcategories (${selectedFilterSubcategories.length} selected)",
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: selectedFilterSubcategories.isNotEmpty
                                ? Text(
                                    selectedFilterSubcategories.join(', '),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            children: [
                              CheckboxListTile(
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  "None (No Subcategory)",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                value: selectedFilterSubcategories.contains(
                                  'None',
                                ),
                                onChanged: (bool? checked) {
                                  setModalState(() {
                                    checked == true
                                        ? selectedFilterSubcategories.add(
                                            'None',
                                          )
                                        : selectedFilterSubcategories.remove(
                                            'None',
                                          );
                                  });
                                  setState(() {});
                                },
                              ),
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),

                              ...structure.entries.map((entry) {
                                final parentCategoryName = entry.key;
                                final subcategoriesList = entry.value;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        12,
                                        16,
                                        4,
                                      ),
                                      child: Text(
                                        parentCategoryName.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _getDeterministicColor(
                                            parentCategoryName,
                                          ),
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                    ...subcategoriesList.map((sub) {
                                      final isSel = selectedFilterSubcategories
                                          .contains(sub);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                        ),
                                        child: CheckboxListTile(
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          title: Text(
                                            sub,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                          value: isSel,
                                          onChanged: (bool? checked) {
                                            setModalState(() {
                                              checked == true
                                                  ? selectedFilterSubcategories
                                                        .add(sub)
                                                  : selectedFilterSubcategories
                                                        .remove(sub);
                                            });
                                            setState(() {});
                                          },
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              }),
                            ],
                          );
                        },
                      ),

                    ExpansionTile(
                      leading: const Icon(
                        Icons.low_priority,
                        color: Colors.purpleAccent,
                        size: 20,
                      ),
                      title: Text(
                        selectedFilterUrgencies.isEmpty
                            ? "All Urgency Tiers"
                            : "Urgencies (${selectedFilterUrgencies.length} selected)",
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: selectedFilterUrgencies.isNotEmpty
                          ? Text(
                              selectedFilterUrgencies.join(', '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      children: availUrgencies
                          .where((u) => !u.startsWith('⏰'))
                          .map((urg) {
                            final isSel = selectedFilterUrgencies.contains(urg);
                            return CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                urg,
                                style: const TextStyle(fontSize: 13),
                              ),
                              value: isSel,
                              onChanged: (bool? checked) {
                                setModalState(() {
                                  checked == true
                                      ? selectedFilterUrgencies.add(urg)
                                      : selectedFilterUrgencies.remove(urg);
                                });
                                setState(() {});
                              },
                            );
                          })
                          .toList(),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.blueAccent,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "APPLY FILTERS",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // STATUS MATRIX PILL: Persistent colored outline (unselected) vs solid colored fill context (selected)
  Widget _buildStatusMatrixPill({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: activeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isActive ? Colors.black : activeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? Colors.black : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // THE 5-LINE IMMERSIVE FOCUSED OVERLAY ENGINE
  void _showFocusedTaskOverlay(BuildContext context, Task task) {
    final TextEditingController subTaskCtl = TextEditingController();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss Focus View",
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogCtx, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setOverlayState) {
            final bool hasRepeat =
                task.isRepeating == 1 && task.repeatType != 'None';

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 32,
                ),
                child: Hero(
                  tag: 'task_card_${task.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 12),
                      child: Material(
                        color: const Color(0xFF0C0C0C).withValues(alpha: 0.9),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.8,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LINE 1: High-Contrast Heading Layout Track
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        decoration: task.isCompleted == 1
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.grey,
                                      size: 22,
                                    ),
                                    onPressed: () => Navigator.pop(dialogCtx),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // LINE 2: Solid-Filled Taxonomy Pills Row
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getDeterministicColor(
                                        task.category,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      task.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _getDeterministicColor(
                                          task.category,
                                        ),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (task.subcategory.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getDeterministicColor(
                                          task.subcategory,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        task.subcategory,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _getDeterministicColor(
                                            task.subcategory,
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getUrgencyColor(
                                        task.urgency,
                                      ).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      task.urgency,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _getUrgencyColor(task.urgency),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // LINE 3: Full-Status Grid Matrix (Persistent Custom Colors Vector Framework)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _buildStatusMatrixPill(
                                    icon: Icons.calendar_month,
                                    label: "Calendar",
                                    isActive: task.syncToCalendar == 1,
                                    activeColor: Colors.blueAccent,
                                  ),
                                  _buildStatusMatrixPill(
                                    icon: Icons.notifications_active,
                                    label: "Notify",
                                    isActive: task.setNotification == 1,
                                    activeColor: Colors.amber,
                                  ),
                                  _buildStatusMatrixPill(
                                    icon: Icons.alarm,
                                    label: "Alarm",
                                    isActive: task.setAlarm == 1,
                                    activeColor: Colors.redAccent,
                                  ),
                                  _buildStatusMatrixPill(
                                    icon: Icons.loop,
                                    label: hasRepeat ? task.repeatType : "None",
                                    isActive: hasRepeat,
                                    activeColor: Colors.purpleAccent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // LINE 4: Arrow-Indented Description Box Frame
                              if (task.description.isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        top: 2,
                                        right: 6,
                                      ),
                                      child: Icon(
                                        Icons.subdirectory_arrow_right,
                                        size: 14,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.04,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          task.description,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xD9FFFFFF),
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],

                              const Divider(color: Colors.white12, height: 1),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  "SUB-TASKS",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),

                              // LINE 5 ONWARDS: Subtasks Integration Tree View
                              Expanded(
                                child: FutureBuilder<List<SubTask>>(
                                  future: DBHelper.getSubTasks(task.id!),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    final subtasksList = snapshot.data!;

                                    if (subtasksList.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          "No objectives added yet.",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      itemCount: subtasksList.length,
                                      itemBuilder: (context, sIdx) {
                                        final sub = subtasksList[sIdx];
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          leading: Checkbox(
                                            value: sub.isCompleted == 1,
                                            onChanged: (bool? val) async {
                                              sub.isCompleted = val == true
                                                  ? 1
                                                  : 0;
                                              await DBHelper.updateSubTask(sub);

                                              var updatedTasks =
                                                  await DBHelper.getTasks();
                                              var checkedParentState =
                                                  updatedTasks.firstWhere(
                                                    (e) => e.id == task.id,
                                                  );

                                              if (checkedParentState
                                                      .isCompleted ==
                                                  1) {
                                                if (dialogCtx.mounted) {
                                                  Navigator.pop(dialogCtx);
                                                }
                                              } else {
                                                setOverlayState(() {});
                                              }
                                              _refresh();
                                            },
                                          ),
                                          title: Text(
                                            sub.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: const Color(0xE6FFFFFF),
                                              decoration: sub.isCompleted == 1
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 16,
                                              color: Colors.redAccent,
                                            ),
                                            onPressed: () async {
                                              await DBHelper.deleteSubTask(
                                                sub.id!,
                                              );
                                              setOverlayState(() {});
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: subTaskCtl,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          hintText: "Add nested objective...",
                                          border: UnderlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add_box_rounded,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                      onPressed: () async {
                                        if (subTaskCtl.text.trim().isNotEmpty) {
                                          await DBHelper.insertSubTask(
                                            SubTask(
                                              parentId: task.id!,
                                              title: subTaskCtl.text.trim(),
                                            ),
                                          );
                                          subTaskCtl.clear();
                                          setOverlayState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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

    final Color categoryColor = _getDeterministicColor(task.category);
    final Color subcategoryColor = _getDeterministicColor(task.subcategory);
    final Color urgencyColor = _getUrgencyColor(task.urgency);
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
            // Leftmost side-by-side tri-color army badge tracking strips
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 4, color: categoryColor),
                Container(width: 4, color: subcategoryColor),
                Container(width: 4, color: urgencyColor),
              ],
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

                      // Core Text Body Section (Title + Metadata + Optional Truncated Description Preview)
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

                      // DETACHED CONTROLS & SEPARATED MATRIX ROW CLUSTER
                      IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ROW 1: Action Controls (Right-aligned)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
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
                                const SizedBox(
                                  width: 12,
                                ), // Clean uniform horizontal button gap
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

                            // ROW 2: Selected active indicators nested perfectly straight BELOW the buttons panel, justified right
                            if (task.syncToCalendar == 1 ||
                                task.setNotification == 1 ||
                                task.setAlarm == 1 ||
                                hasRepeatActive) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (task.syncToCalendar == 1)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.calendar_month,
                                        size: 14,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  if (task.setNotification == 1)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.notifications_active,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  if (task.setAlarm == 1)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.alarm,
                                        size: 14,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  if (hasRepeatActive)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
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
      backgroundColor: const Color(0xFF0C0C0C),
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
