import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../models.dart';
import '../widgets/task_utils.dart';

class TaskCreateSheet extends StatefulWidget {
  final Task? existingTask;
  final VoidCallback onRefresh;

  const TaskCreateSheet({
    super.key,
    required this.existingTask,
    required this.onRefresh,
  });

  @override
  State<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends State<TaskCreateSheet> {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;

  late String selectedCat;
  late String selectedSubCat;
  late String selectedUrg;
  late String selectedRepeat;

  DateTime? deadlineDate;
  TimeOfDay? deadlineTime;

  late bool isRepeating;
  late bool syncCal;
  late bool setNotify;
  late bool setAlarm;

  List<String> categories = [];
  List<String> urgencies = [];
  List<String> subcategories = [];

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.existingTask?.title ?? "");
    descCtrl = TextEditingController(
      text: widget.existingTask?.description ?? "",
    );

    selectedCat = widget.existingTask?.category ?? 'Study';
    selectedSubCat = widget.existingTask?.subcategory ?? 'None';
    if (selectedSubCat.isEmpty) selectedSubCat = 'None';
    selectedUrg = widget.existingTask?.urgency ?? 'Today';
    if (selectedUrg.startsWith('⏰')) {
      selectedUrg = 'Today';
    }
    selectedRepeat = widget.existingTask?.repeatType ?? 'None';

    if (widget.existingTask?.deadline != null) {
      DateTime parsed = DateTime.parse(widget.existingTask!.deadline!);
      deadlineDate = DateTime(parsed.year, parsed.month, parsed.day);
      if (!widget.existingTask!.deadline!.contains('T23:59:59')) {
        deadlineTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      }
    }

    isRepeating = widget.existingTask?.isRepeating == 1;
    syncCal = widget.existingTask?.syncToCalendar == 1;
    setNotify = widget.existingTask?.setNotification == 1;
    setAlarm = widget.existingTask?.setAlarm == 1;

    _loadData();
  }

  Future<void> _loadData() async {
    List<String> cats = await DBHelper.getCategories();
    List<String> urgs = await DBHelper.getUrgencies();
    List<String> subs = await DBHelper.getSubcategories(selectedCat);

    if (!cats.contains(selectedCat) && selectedCat.isNotEmpty) {
      cats.add(selectedCat);
    }
    if (!urgs.contains(selectedUrg) && selectedUrg.isNotEmpty) {
      urgs.add(selectedUrg);
    }
    cats.add("+ Add New Category");
    urgs.add("+ Add New Urgency");

    if (mounted) {
      setState(() {
        categories = cats;
        urgencies = urgs;
        subcategories = subs;
      });
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        bool isTitleValid = titleCtrl.text.trim().isNotEmpty;
        final cleanUserUrgencies = urgencies
            .where((u) => !u.startsWith('⏰'))
            .toList();

        String? dynamicUrgency;
        if (deadlineDate != null) {
          DateTime targetDate;
          if (deadlineTime != null) {
            targetDate = DateTime(
              deadlineDate!.year,
              deadlineDate!.month,
              deadlineDate!.day,
              deadlineTime!.hour,
              deadlineTime!.minute,
            );
          } else {
            targetDate = DateTime(
              deadlineDate!.year,
              deadlineDate!.month,
              deadlineDate!.day,
              23,
              59,
              59,
            );
          }
          final difference = targetDate.difference(DateTime.now());
          if (difference.isNegative || difference.inHours <= 6) {
            dynamicUrgency = '⏰ Within 6 Hours';
          } else if (difference.inHours <= 12) {
            dynamicUrgency = '⏰ Within 12 Hours';
          } else if (difference.inHours <= 24) {
            dynamicUrgency = '⏰ Within 24 Hours';
          } else if (difference.inDays <= 7) {
            dynamicUrgency = '⏰ Within 1 Week';
          } else if (difference.inDays <= 30) {
            dynamicUrgency = '⏰ Within 1 Month';
          } else {
            dynamicUrgency = '⏰ Within 1 Month';
          }
        }

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

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 12),
            child: Material(
              color: const Color(0xFF0C0C0C).withValues(alpha: 0.9),
              child: Padding(
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
                          widget.existingTask == null ? "New Task" : "Edit Task",
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
                        decoration: buildFormInputDecoration("Title *"),
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
                              decoration: buildFormInputDecoration(
                                "Category",
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
                                  handleCustomTaxonomy(
                                    'Category',
                                    selectedCat,
                                  );
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
                              initialValue:
                                  dynamicUrgency ??
                                  (cleanUserUrgencies.contains(selectedUrg)
                                      ? selectedUrg
                                      : cleanUserUrgencies.isNotEmpty ? cleanUserUrgencies.first : 'Today'),
                              isExpanded: true,
                              decoration: buildFormInputDecoration(
                                "Urgency",
                              ),
                              items: dynamicUrgency != null
                                  ? [
                                      DropdownMenuItem(
                                        value: dynamicUrgency,
                                        child: Text(
                                          dynamicUrgency,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ),
                                    ]
                                  : cleanUserUrgencies
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(
                                              e,
                                              overflow:
                                                  TextOverflow.ellipsis,
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
                              onChanged: dynamicUrgency != null
                                  ? null
                                  : (v) {
                                      if (v == "+ Add New Urgency") {
                                        handleCustomTaxonomy(
                                          'Urgency',
                                          selectedUrg,
                                        );
                                      } else {
                                        setModalState(
                                          () => selectedUrg = v!,
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue:
                            visibleSubCats.contains(selectedSubCat)
                            ? selectedSubCat
                            : 'None',
                        isExpanded: true,
                        decoration: buildFormInputDecoration(
                          "Subcategory (Optional)",
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
                            handleCustomTaxonomy(
                              'Subcategory',
                              selectedSubCat,
                            );
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
                          labelStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.format_list_bulleted,
                              color: Colors.grey,
                            ),
                            onPressed: insertBullet,
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.white24,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.all(
                              Radius.circular(4),
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.blueAccent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.all(
                              Radius.circular(4),
                            ),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(4),
                            ),
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
                              : DateFormat(
                                  'MMM dd, yyyy',
                                ).format(deadlineDate!),
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
                            setModalState(() => deadlineDate = datePicked);
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
                                  onPressed: () => setModalState(
                                    () => deadlineTime = null,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                ),
                          onTap: () async {
                            TimeOfDay? timePicked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (timePicked != null) {
                              setModalState(
                                () => deadlineTime = timePicked,
                              );
                            }
                          },
                        ),
                      const Divider(),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.loop,
                              color: Colors.purpleAccent,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Repeat Rule',
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
                                  initialValue: selectedRepeat == 'None'
                                      ? 'Daily'
                                      : selectedRepeat,
                                  decoration: buildFormInputDecoration(
                                    "Interval",
                                  ),
                                  items:
                                      [
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
                                  onChanged: (v) => setModalState(
                                    () => selectedRepeat = v!,
                                  ),
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
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModalState(() => syncCal = !syncCal),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: syncCal
                                      ? Colors.blueAccent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.blueAccent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: syncCal
                                          ? Colors.black
                                          : Colors.blueAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        "Calendar",
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: syncCal
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: syncCal
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(
                                () => setNotify = !setNotify,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: setNotify
                                      ? Colors.amber
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.amber,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_active,
                                      size: 14,
                                      color: setNotify
                                          ? Colors.black
                                          : Colors.amber,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        "Notify",
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: setNotify
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: setNotify
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setModalState(() => setAlarm = !setAlarm),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: setAlarm
                                      ? Colors.redAccent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.redAccent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.alarm,
                                      size: 14,
                                      color: setAlarm
                                          ? Colors.black
                                          : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        "Alarm",
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: setAlarm
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: setAlarm
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (!isTitleValid)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "⚠️ A title is required to save this task.",
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 13,
                            ),
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
                                    widget.existingTask ??
                                    Task(
                                      title: "",
                                      category: "",
                                      urgency: "",
                                    );
                                t.title = title;
                                t.description = descCtrl.text.trim();
                                t.category = selectedCat;
                                t.subcategory = selectedSubCat == 'None'
                                    ? ''
                                    : selectedSubCat;
                                t.urgency = dynamicUrgency ?? selectedUrg;

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

                                if (widget.existingTask == null) {
                                  await DBHelper.insertTask(t);
                                } else {
                                  await DBHelper.updateTask(t);
                                }
                                widget.onRefresh();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            : null,
                        child: Text(
                          "SAVE TASK",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isTitleValid
                                ? Colors.white
                                : Colors.white38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
