import 'package:flutter/material.dart';
import 'dart:ui';
import '../db_helper.dart';
import '../models.dart';
import '../widgets/task_utils.dart';

void showFocusedTaskOverlay(BuildContext context, Task task, VoidCallback onRefresh) {
  final TextEditingController descCtl = TextEditingController(
    text: task.description,
  );
  bool isDescExpanded = false;
  int? editingSubTaskId;
  TextEditingController? editingSubTitleController;
  bool isRepeatDropdownOpen = false;

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
                horizontal: 14,
                vertical: 20,
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
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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

                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                            decoration: BoxDecoration(
                                              color: getDeterministicColor(
                                                task.category,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: getDeterministicColor(
                                                  task.category,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.folder_outlined,
                                                  size: 12,
                                                  color:
                                                      getDeterministicColor(
                                                        task.category,
                                                      ),
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    task.category,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        Expanded(
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                            decoration: BoxDecoration(
                                              color:
                                                  task.subcategory.isNotEmpty
                                                  ? getDeterministicColor(
                                                      task.subcategory,
                                                    ).withValues(alpha: 0.15)
                                                  : Colors.white.withValues(
                                                      alpha: 0.03,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color:
                                                    task
                                                        .subcategory
                                                        .isNotEmpty
                                                    ? getDeterministicColor(
                                                        task.subcategory,
                                                      )
                                                    : Colors.white12,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.layers_outlined,
                                                  size: 12,
                                                  color:
                                                      task
                                                          .subcategory
                                                          .isNotEmpty
                                                      ? getDeterministicColor(
                                                          task.subcategory,
                                                        )
                                                      : Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    task
                                                            .subcategory
                                                            .isNotEmpty
                                                        ? task.subcategory
                                                        : "None",
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          task
                                                              .subcategory
                                                              .isNotEmpty
                                                          ? Colors.white
                                                          : Colors.grey,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        Expanded(
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                            decoration: BoxDecoration(
                                              color: getUrgencyColor(
                                                task.urgency,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: getUrgencyColor(
                                                  task.urgency,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.star_outline,
                                                  size: 12,
                                                  color: getUrgencyColor(
                                                    task.urgency,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    task.urgency,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildStatusMatrixPill(
                                            icon: Icons.calendar_month,
                                            label: "Calendar",
                                            isActive:
                                                task.syncToCalendar == 1,
                                            activeColor: Colors.blueAccent,
                                            onTap: () async {
                                              task.syncToCalendar =
                                                  task.syncToCalendar == 1
                                                  ? 0
                                                  : 1;
                                              await DBHelper.updateTask(task);
                                              setOverlayState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildStatusMatrixPill(
                                            icon: Icons.notifications_active,
                                            label: "Notify",
                                            isActive:
                                                task.setNotification == 1,
                                            activeColor: Colors.amber,
                                            onTap: () async {
                                              task.setNotification =
                                                  task.setNotification == 1
                                                  ? 0
                                                  : 1;
                                              await DBHelper.updateTask(task);
                                              setOverlayState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildStatusMatrixPill(
                                            icon: Icons.alarm,
                                            label: "Alarm",
                                            isActive: task.setAlarm == 1,
                                            activeColor: Colors.redAccent,
                                            onTap: () async {
                                              task.setAlarm =
                                                  task.setAlarm == 1 ? 0 : 1;
                                              await DBHelper.updateTask(task);
                                              setOverlayState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            setOverlayState(() {
                                              isRepeatDropdownOpen =
                                                  !isRepeatDropdownOpen;
                                            });
                                          },
                                          child: Container(
                                            width: double.infinity,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 8,
                                                ),
                                            decoration: BoxDecoration(
                                              color: hasRepeat
                                                  ? Colors.purpleAccent
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.purpleAccent,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.loop,
                                                      size: 14,
                                                      color: hasRepeat
                                                          ? Colors.black
                                                          : Colors
                                                                .purpleAccent,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      "Repeat: ${hasRepeat ? task.repeatType : "None"}",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: hasRepeat
                                                            ? FontWeight.bold
                                                            : FontWeight
                                                                  .normal,
                                                        color: hasRepeat
                                                            ? Colors.black
                                                            : Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Icon(
                                                  isRepeatDropdownOpen
                                                      ? Icons.arrow_drop_up
                                                      : Icons.arrow_drop_down,
                                                  size: 18,
                                                  color: hasRepeat
                                                      ? Colors.black
                                                      : Colors.purpleAccent,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isRepeatDropdownOpen) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E1E1E),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.purpleAccent
                                                    .withValues(alpha: 0.5),
                                                width: 1,
                                              ),
                                            ),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 4,
                                                ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children:
                                                  [
                                                    'None',
                                                    'Daily',
                                                    'Weekly',
                                                    'Biweekly',
                                                    'Monthly',
                                                  ].map((String val) {
                                                    final isSelected =
                                                        task.repeatType ==
                                                        val;
                                                    return InkWell(
                                                      onTap: () async {
                                                        task.repeatType = val;
                                                        task.isRepeating =
                                                            val == 'None'
                                                            ? 0
                                                            : 1;
                                                        await DBHelper.updateTask(
                                                          task,
                                                        );
                                                        setOverlayState(() {
                                                          isRepeatDropdownOpen =
                                                              false;
                                                        });
                                                      },
                                                      child: Container(
                                                        width:
                                                            double.infinity,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 16,
                                                              vertical: 10,
                                                            ),
                                                        color: isSelected
                                                            ? Colors
                                                                  .purpleAccent
                                                                  .withValues(
                                                                    alpha:
                                                                        0.15,
                                                                  )
                                                            : Colors
                                                                  .transparent,
                                                        child: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              val,
                                                              style: TextStyle(
                                                                color:
                                                                    isSelected
                                                                    ? Colors
                                                                          .purpleAccent
                                                                    : Colors
                                                                          .white,
                                                                fontWeight:
                                                                    isSelected
                                                                    ? FontWeight
                                                                          .bold
                                                                    : FontWeight
                                                                          .normal,
                                                              ),
                                                            ),
                                                            if (isSelected)
                                                              const Icon(
                                                                Icons.check,
                                                                color: Colors
                                                                    .purpleAccent,
                                                                size: 16,
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "DESCRIPTION",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blueAccent,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isDescExpanded
                                                ? Icons.keyboard_arrow_down
                                                : Icons.keyboard_arrow_right,
                                            size: 20,
                                            color: Colors.blueAccent,
                                          ),
                                          onPressed: () => setOverlayState(
                                            () => isDescExpanded =
                                                !isDescExpanded,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(
                                          4,
                                        ),
                                        border: Border.all(
                                          color: Colors.white24,
                                          width: 1,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: descCtl,
                                        maxLines: isDescExpanded ? null : 1,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xD9FFFFFF),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: "Add details/notes...",
                                          hintStyle: TextStyle(
                                            color: Colors.white30,
                                            fontSize: 14,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: (v) async {
                                          task.description = v;
                                          await DBHelper.updateTask(task);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    const Divider(
                                      color: Colors.white12,
                                      height: 1,
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
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

                                    FutureBuilder<List<SubTask>>(
                                      future: DBHelper.getSubTasks(task.id!),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Center(
                                            child:
                                                CircularProgressIndicator(),
                                          );
                                        }
                                        final subtasksList = snapshot.data!;

                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (subtasksList.isNotEmpty)
                                              ListView.builder(
                                                shrinkWrap: true,
                                                padding: EdgeInsets.zero,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                itemCount:
                                                    subtasksList.length,
                                                itemBuilder: (context, sIdx) {
                                                  final sub =
                                                      subtasksList[sIdx];
                                                  if (sub.id != null &&
                                                      sub.id ==
                                                          editingSubTaskId) {
                                                    editingSubTitleController ??=
                                                        TextEditingController(
                                                          text: sub.title,
                                                        );
                                                    final Color
                                                    categoryColor =
                                                        getDeterministicColor(
                                                          task.category,
                                                        );
                                                    final Color
                                                    subcategoryColor =
                                                        getDeterministicColor(
                                                          task.subcategory,
                                                        );
                                                    final Color urgencyColor =
                                                        getUrgencyColor(
                                                          sub.urgency,
                                                        );

                                                    return Card(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 4,
                                                          ),
                                                      color: Colors.grey[900],
                                                      clipBehavior:
                                                          Clip.antiAlias,
                                                      child: IntrinsicHeight(
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .stretch,
                                                          children: [
                                                            SizedBox(
                                                              width: 18,
                                                              child: Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .stretch,
                                                                children: [
                                                                  Expanded(
                                                                    child: Container(
                                                                      color:
                                                                          categoryColor,
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    child: Container(
                                                                      color:
                                                                          subcategoryColor,
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                    child: Container(
                                                                      color:
                                                                          urgencyColor,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          6,
                                                                    ),
                                                                child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: TextField(
                                                                        controller:
                                                                            editingSubTitleController,
                                                                        autofocus:
                                                                            true,
                                                                        maxLines:
                                                                            1,
                                                                        textInputAction:
                                                                            TextInputAction.done,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              13,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                        decoration: const InputDecoration(
                                                                          hintText:
                                                                              "Subtask title...",
                                                                          border:
                                                                              InputBorder.none,
                                                                          isDense:
                                                                              true,
                                                                        ),
                                                                        onSubmitted: (v) async {
                                                                          final titleText =
                                                                              v.trim();
                                                                          if (titleText.isNotEmpty) {
                                                                            sub.title = titleText;
                                                                            await DBHelper.updateSubTask(
                                                                              sub,
                                                                            );
                                                                            SubTask
                                                                            nextSub = SubTask(
                                                                              parentId: task.id!,
                                                                              title: '',
                                                                              urgency: task.urgency,
                                                                              syncToCalendar: task.syncToCalendar,
                                                                              setNotification: task.setNotification,
                                                                              setAlarm: task.setAlarm,
                                                                              repeatType: task.repeatType,
                                                                            );
                                                                            final nextId = await DBHelper.insertSubTask(
                                                                              nextSub,
                                                                            );
                                                                            setOverlayState(
                                                                              () {
                                                                                editingSubTaskId = nextId;
                                                                                editingSubTitleController = TextEditingController(
                                                                                  text: '',
                                                                                );
                                                                              },
                                                                            );
                                                                          }
                                                                        },
                                                                      ),
                                                                    ),
                                                                    IconButton(
                                                                      icon: const Icon(
                                                                        Icons
                                                                            .check,
                                                                        color:
                                                                            Colors.green,
                                                                        size:
                                                                            18,
                                                                      ),
                                                                      onPressed: () async {
                                                                        final titleText =
                                                                            (editingSubTitleController?.text ??
                                                                                    '')
                                                                                .trim();
                                                                        if (titleText
                                                                            .isEmpty) {
                                                                          await DBHelper.deleteSubTask(
                                                                            sub.id!,
                                                                          );
                                                                          setOverlayState(() {
                                                                            editingSubTaskId = null;
                                                                            editingSubTitleController = null;
                                                                          });
                                                                        } else {
                                                                          sub.title =
                                                                              titleText;
                                                                          await DBHelper.updateSubTask(
                                                                            sub,
                                                                          );
                                                                          setOverlayState(() {
                                                                            editingSubTaskId = null;
                                                                            editingSubTitleController = null;
                                                                          });
                                                                        }
                                                                      },
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  final Color categoryColor =
                                                      getDeterministicColor(
                                                        task.category,
                                                      );
                                                  final Color
                                                  subcategoryColor =
                                                      getDeterministicColor(
                                                        task.subcategory,
                                                      );
                                                  final Color urgencyColor =
                                                      getUrgencyColor(
                                                        sub.urgency,
                                                      );

                                                  return Card(
                                                    margin:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 4,
                                                        ),
                                                    color: Colors.grey[900],
                                                    clipBehavior:
                                                        Clip.antiAlias,
                                                    child: IntrinsicHeight(
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          SizedBox(
                                                            width: 18,
                                                            child: Row(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                Expanded(
                                                                  child: Container(
                                                                    color:
                                                                        categoryColor,
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: Container(
                                                                    color:
                                                                        subcategoryColor,
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: Container(
                                                                    color:
                                                                        urgencyColor,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        6,
                                                                  ),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    children: [
                                                                      Checkbox(
                                                                        materialTapTargetSize:
                                                                            MaterialTapTargetSize.shrinkWrap,
                                                                        visualDensity:
                                                                            VisualDensity.compact,
                                                                        value:
                                                                            sub.isCompleted ==
                                                                            1,
                                                                        onChanged:
                                                                            (
                                                                              bool?
                                                                              val,
                                                                            ) async {
                                                                              sub.isCompleted =
                                                                                  val ==
                                                                                      true
                                                                                  ? 1
                                                                                  : 0;
                                                                              await DBHelper.updateSubTask(
                                                                                sub,
                                                                              );
                                                                              var updatedTasks = await DBHelper.getTasks();
                                                                              var checkedParentState = updatedTasks.firstWhere(
                                                                                (
                                                                                  e,
                                                                                ) =>
                                                                                    e.id ==
                                                                                    task.id,
                                                                              );
                                                                              if (checkedParentState.isCompleted ==
                                                                                  1) {
                                                                                if (dialogCtx.mounted) {
                                                                                  Navigator.pop(
                                                                                    dialogCtx,
                                                                                  );
                                                                                }
                                                                              } else {
                                                                                setOverlayState(
                                                                                  () {},
                                                                                );
                                                                              }
                                                                              onRefresh();
                                                                            },
                                                                      ),
                                                                      Expanded(
                                                                        child: InkWell(
                                                                          onTap: () {
                                                                            setOverlayState(
                                                                              () {
                                                                                editingSubTaskId = sub.id;
                                                                                editingSubTitleController = TextEditingController(
                                                                                  text: sub.title,
                                                                                );
                                                                              },
                                                                            );
                                                                          },
                                                                          child: Text(
                                                                            sub.title.isEmpty
                                                                                ? '(no title)'
                                                                                : sub.title,
                                                                            style: TextStyle(
                                                                              fontSize: 13,
                                                                              color: const Color(
                                                                                0xE6FFFFFF,
                                                                              ),
                                                                              decoration:
                                                                                  sub.isCompleted ==
                                                                                      1
                                                                                  ? TextDecoration.lineThrough
                                                                                  : null,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      IconButton(
                                                                        icon: const Icon(
                                                                          Icons.remove_circle_outline,
                                                                          size:
                                                                              16,
                                                                          color:
                                                                              Colors.redAccent,
                                                                        ),
                                                                        onPressed: () async {
                                                                          await DBHelper.deleteSubTask(
                                                                            sub.id!,
                                                                          );
                                                                          setOverlayState(
                                                                            () {},
                                                                          );
                                                                        },
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  Padding(
                                                                    padding: const EdgeInsets.only(
                                                                      left:
                                                                          36,
                                                                      top: 4,
                                                                      bottom:
                                                                          4,
                                                                    ),
                                                                    child: Wrap(
                                                                      spacing:
                                                                          6,
                                                                      runSpacing:
                                                                          4,
                                                                      children: [
                                                                        buildSubTaskUrgencyPill(
                                                                          sub,
                                                                          setOverlayState,
                                                                        ),
                                                                        buildSubTaskReminderPill(
                                                                          icon:
                                                                              Icons.calendar_month,
                                                                          isActive:
                                                                              sub.syncToCalendar ==
                                                                              1,
                                                                          activeColor:
                                                                              Colors.blueAccent,
                                                                          onTap: () async {
                                                                            sub.syncToCalendar =
                                                                                sub.syncToCalendar ==
                                                                                    1
                                                                                ? 0
                                                                                : 1;
                                                                            await DBHelper.updateSubTask(
                                                                              sub,
                                                                            );
                                                                            setOverlayState(
                                                                              () {},
                                                                            );
                                                                          },
                                                                        ),
                                                                        buildSubTaskReminderPill(
                                                                          icon:
                                                                              Icons.notifications_active,
                                                                          isActive:
                                                                              sub.setNotification ==
                                                                              1,
                                                                          activeColor:
                                                                              Colors.amber,
                                                                          onTap: () async {
                                                                            sub.setNotification =
                                                                                sub.setNotification ==
                                                                                    1
                                                                                ? 0
                                                                                : 1;
                                                                            await DBHelper.updateSubTask(
                                                                              sub,
                                                                            );
                                                                            setOverlayState(
                                                                              () {},
                                                                            );
                                                                          },
                                                                        ),
                                                                        buildSubTaskReminderPill(
                                                                          icon:
                                                                              Icons.alarm,
                                                                          isActive:
                                                                              sub.setAlarm ==
                                                                              1,
                                                                          activeColor:
                                                                              Colors.redAccent,
                                                                          onTap: () async {
                                                                            sub.setAlarm =
                                                                                sub.setAlarm ==
                                                                                    1
                                                                                ? 0
                                                                                : 1;
                                                                            await DBHelper.updateSubTask(
                                                                              sub,
                                                                            );
                                                                            setOverlayState(
                                                                              () {},
                                                                            );
                                                                          },
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            if (editingSubTaskId == null)
                                              InkWell(
                                                onTap: () async {
                                                  SubTask sub = SubTask(
                                                    parentId: task.id!,
                                                    title: '',
                                                    urgency: task.urgency,
                                                    syncToCalendar:
                                                        task.syncToCalendar,
                                                    setNotification:
                                                        task.setNotification,
                                                    setAlarm: task.setAlarm,
                                                    repeatType:
                                                        task.repeatType,
                                                  );
                                                  final id =
                                                      await DBHelper.insertSubTask(
                                                        sub,
                                                      );
                                                  sub.id = id;
                                                  setOverlayState(() {
                                                    editingSubTaskId = id;
                                                    editingSubTitleController =
                                                        TextEditingController(
                                                          text: '',
                                                        );
                                                  });
                                                },
                                                child: const Padding(
                                                  padding:
                                                      EdgeInsets.symmetric(
                                                        vertical: 6,
                                                        horizontal: 4,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .add_circle_outline,
                                                        color: Colors.green,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Add new subtask...',
                                                        style: TextStyle(
                                                          color: Colors.green,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
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
  ).then((_) => onRefresh());
}

Widget _buildStatusMatrixPill({
  required IconData icon,
  required String label,
  required bool isActive,
  required Color activeColor,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? activeColor : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: isActive ? Colors.black : activeColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                height: 1.1,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.black : Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
