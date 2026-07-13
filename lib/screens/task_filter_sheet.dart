import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../widgets/task_utils.dart';

class TaskFilterSheet extends StatefulWidget {
  final List<String> selectedFilterCategories;
  final List<String> selectedFilterSubcategories;
  final List<String> selectedFilterUrgencies;
  final VoidCallback onStateChanged;

  const TaskFilterSheet({
    super.key,
    required this.selectedFilterCategories,
    required this.selectedFilterSubcategories,
    required this.selectedFilterUrgencies,
    required this.onStateChanged,
  });

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  List<String> availCats = [];
  List<String> availUrgencies = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<String> cats = await DBHelper.getCategories();
    List<String> urgs = await DBHelper.getUrgencies();
    if (mounted) {
      setState(() {
        availCats = cats;
        availUrgencies = urgs;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    setState(() {
                      widget.selectedFilterCategories.clear();
                      widget.selectedFilterSubcategories.clear();
                      widget.selectedFilterUrgencies.clear();
                    });
                    widget.onStateChanged();
                  },
                  child: const Text(
                    "Reset Filters",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
            const Divider(),

            // Integrated Category + Submenu Matrix Section
            ExpansionTile(
              leading: const Icon(
                Icons.category,
                color: Colors.blueAccent,
                size: 20,
              ),
              title: Text(
                widget.selectedFilterCategories.isEmpty
                    ? "Categories"
                    : "Categories (${widget.selectedFilterCategories.length} selected)",
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                "(categories → sub categories)",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              children: availCats.map((cat) {
                final isCatSelected = widget.selectedFilterCategories.contains(
                  cat,
                );

                return FutureBuilder<List<String>>(
                  future: DBHelper.getSubcategories(cat),
                  builder: (context, snapshot) {
                    final subs = snapshot.data ?? [];
                    final catColor = getDeterministicColor(cat);

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: isCatSelected,
                                        activeColor: catColor,
                                        onChanged: (bool? checked) {
                                          setState(() {
                                            if (checked == true) {
                                              widget.selectedFilterCategories
                                                  .add(cat);
                                            } else {
                                              widget.selectedFilterCategories
                                                  .remove(cat);
                                              for (var s in subs) {
                                                widget.selectedFilterSubcategories
                                                    .remove(s);
                                              }
                                              widget.selectedFilterSubcategories
                                                  .remove('None');
                                            }
                                          });
                                          widget.onStateChanged();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        cat,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: !isCatSelected || subs.isEmpty
                                      ? const SizedBox.shrink()
                                      : PopupMenuButton<String>(
                                          tooltip:
                                              "Select Subcategories",
                                          offset: const Offset(0, 40),
                                          color: const Color(
                                            0xFF0C0C0C,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                  8,
                                                ),
                                            side: const BorderSide(
                                              color: Colors.white12,
                                            ),
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: catColor
                                                    .withValues(
                                                      alpha: 0.5,
                                                    ),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    4,
                                                  ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    widget.selectedFilterSubcategories
                                                                .contains(
                                                                  'None',
                                                                ) ||
                                                            widget.selectedFilterSubcategories.any(
                                                              (
                                                                s,
                                                              ) => subs
                                                                  .contains(
                                                                    s,
                                                                  ),
                                                            )
                                                        ? "Selective"
                                                        : "All",
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: catColor,
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                    ),
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.arrow_drop_down,
                                                  size: 14,
                                                  color: catColor,
                                                ),
                                              ],
                                            ),
                                          ),
                                          itemBuilder: (BuildContext context) {
                                            return [
                                              PopupMenuItem<String>(
                                                value: "ALL_TRACK",
                                                child: const Text(
                                                  "All (Default)",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              CustomPopupMenuEntry<
                                                String
                                              >(
                                                entryHeight: 48,
                                                child: StatefulBuilder(
                                                  builder: (context, setMenuState) {
                                                    final isSelected =
                                                        widget.selectedFilterSubcategories
                                                            .contains(
                                                              'None',
                                                            );
                                                    return CheckboxListTile(
                                                      controlAffinity:
                                                          ListTileControlAffinity
                                                              .leading,
                                                      title: const Text(
                                                        "None",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .white,
                                                          fontStyle:
                                                              FontStyle
                                                                  .italic,
                                                        ),
                                                      ),
                                                      value: isSelected,
                                                      onChanged: (bool? checked) {
                                                        setState(() {
                                                          if (checked ==
                                                              true) {
                                                            widget.selectedFilterSubcategories
                                                                .add(
                                                                  'None',
                                                                );
                                                          } else {
                                                            widget.selectedFilterSubcategories
                                                                .remove(
                                                                  'None',
                                                                );
                                                          }
                                                        });
                                                        setMenuState(
                                                          () {},
                                                        );
                                                        widget.onStateChanged();
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                              ...subs.map((sub) {
                                                return CustomPopupMenuEntry<
                                                  String
                                                >(
                                                  entryHeight: 48,
                                                  child: StatefulBuilder(
                                                    builder:
                                                        (
                                                          context,
                                                          setMenuState,
                                                        ) {
                                                          final isSelected =
                                                              widget.selectedFilterSubcategories
                                                                  .contains(
                                                                    sub,
                                                                  );
                                                          return CheckboxListTile(
                                                            controlAffinity:
                                                                ListTileControlAffinity
                                                                    .leading,
                                                            title: Text(
                                                              sub,
                                                              style: const TextStyle(
                                                                fontSize:
                                                                    12,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                            value:
                                                                isSelected,
                                                            onChanged:
                                                                (
                                                                  bool?
                                                                  checked,
                                                                ) {
                                                                  setState(() {
                                                                    if (checked ==
                                                                        true) {
                                                                      widget.selectedFilterSubcategories.add(
                                                                        sub,
                                                                      );
                                                                    } else {
                                                                      widget.selectedFilterSubcategories.remove(
                                                                        sub,
                                                                      );
                                                                    }
                                                                  });
                                                                  setMenuState(
                                                                    () {},
                                                                  );
                                                                  widget.onStateChanged();
                                                                },
                                                          );
                                                        },
                                                  ),
                                                );
                                              }),
                                            ];
                                          },
                                          onSelected: (val) {
                                            if (val == "ALL_TRACK") {
                                              setState(() {
                                                for (var s in subs) {
                                                  widget.selectedFilterSubcategories
                                                      .remove(s);
                                                }
                                                widget.selectedFilterSubcategories
                                                    .remove('None');
                                              });
                                              widget.onStateChanged();
                                            }
                                          },
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              }).toList(),
            ),

            ExpansionTile(
              leading: const Icon(
                Icons.low_priority,
                color: Colors.purpleAccent,
                size: 20,
              ),
              title: Text(
                widget.selectedFilterUrgencies.isEmpty
                    ? "Urgency"
                    : "Urgencies (${widget.selectedFilterUrgencies.length} selected)",
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: widget.selectedFilterUrgencies.isNotEmpty
                  ? Text(
                      widget.selectedFilterUrgencies.join(', '),
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
                    final isSel = widget.selectedFilterUrgencies.contains(urg);
                    return CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        urg,
                        style: const TextStyle(fontSize: 13),
                      ),
                      value: isSel,
                      onChanged: (bool? checked) {
                        setState(() {
                          checked == true
                              ? widget.selectedFilterUrgencies.add(urg)
                              : widget.selectedFilterUrgencies.remove(urg);
                        });
                        widget.onStateChanged();
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
              onPressed: () => Navigator.pop(context),
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
  }
}

class CustomPopupMenuEntry<T> extends PopupMenuEntry<T> {
  final double entryHeight;
  final Widget child;

  const CustomPopupMenuEntry({
    super.key,
    required this.entryHeight,
    required this.child,
  });

  @override
  double get height => entryHeight;

  @override
  bool represents(T? value) => false;

  @override
  State<CustomPopupMenuEntry<T>> createState() =>
      _CustomPopupMenuEntryState<T>();
}

class _CustomPopupMenuEntryState<T> extends State<CustomPopupMenuEntry<T>> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
