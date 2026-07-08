import 'package:flutter/material.dart';
import '../db_helper.dart';

class ManageTaxonomies extends StatefulWidget {
  const ManageTaxonomies({super.key});

  @override
  State<ManageTaxonomies> createState() => _ManageTaxonomiesState();
}

class _ManageTaxonomiesState extends State<ManageTaxonomies> {
  List<String> categories = [];
  // Holds unified list of custom tiers mixed with system time anchors
  List<String> unifiedUrgencies = [];
  List<String> activeSubcategories = [];
  String? selectedCategoryForSubs;

  final TextEditingController _catCtl = TextEditingController();
  final TextEditingController _urgCtl = TextEditingController();
  final TextEditingController _subCtl = TextEditingController();

  // Immutable reference markers for system chronological time boundaries
  final List<String> _chronoAnchors = [
    '⏰ Within 6 Hours',
    '⏰ Within 12 Hours',
    '⏰ Within 24 Hours',
    '⏰ Within 1 Week',
    '⏰ Within 1 Month',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    categories = await DBHelper.getCategories();
    List<String> dbUrgencies = await DBHelper.getUrgencies();

    // Construct unified tracking array avoiding duplicate anchor insertions
    List<String> rawList = [];
    for (var item in dbUrgencies) {
      rawList.add(item);
    }

    // If database is initialized or cleared, ensure anchors exist in memory list
    for (var anchor in _chronoAnchors) {
      if (!rawList.contains(anchor)) {
        rawList.add(anchor);
      }
    }

    if (selectedCategoryForSubs == null && categories.isNotEmpty) {
      selectedCategoryForSubs = categories.first;
    }

    if (selectedCategoryForSubs != null) {
      activeSubcategories = await DBHelper.getSubcategories(
        selectedCategoryForSubs!,
      );
    }
    setState(() {
      unifiedUrgencies = rawList;
    });
  }

  Future<void> _updateUrgencyOrder() async {
    // Process entire unified hierarchy chain and map position indices to database weights
    for (int i = 0; i < unifiedUrgencies.length; i++) {
      String name = unifiedUrgencies[i];
      if (_chronoAnchors.contains(name)) {
        // If it's a dynamic time anchor, upsert its record or force check its tracking
        await DBHelper.insertUrgency(name, i);
      }
      await DBHelper.updateUrgencyWeight(name, i);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Configuration')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // PANEL 1: CATEGORIES POOL CONFIGURATION
          Card(
            color: Colors.grey[900],
            child: ExpansionTile(
              leading: const Icon(Icons.category, color: Colors.blueAccent),
              title: const Text(
                'Categories Pool',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: categories
                            .map(
                              (c) => Chip(
                                label: Text(
                                  c,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                visualDensity: VisualDensity.compact,
                                onDeleted: () async {
                                  await DBHelper.deleteCategory(c);
                                  if (selectedCategoryForSubs == c) {
                                    selectedCategoryForSubs = null;
                                  }
                                  _load();
                                },
                              ),
                            )
                            .toList(),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _catCtl,
                              decoration: const InputDecoration(
                                hintText: 'Add new global category',
                                border: UnderlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              if (_catCtl.text.trim().isNotEmpty) {
                                await DBHelper.insertCategory(
                                  _catCtl.text.trim(),
                                );
                                selectedCategoryForSubs = _catCtl.text.trim();
                                _catCtl.clear();
                                _load();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // PANEL 2: RELATIONAL SUBCATEGORIES SUB-ENGINE
          Card(
            color: Colors.grey[900],
            child: ExpansionTile(
              leading: const Icon(Icons.layers, color: Colors.blueAccent),
              title: const Text(
                'Subcategories Engine',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: categories.isEmpty
                      ? const Text(
                          'Create a parent category first.',
                          style: TextStyle(color: Colors.grey),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue:
                                  categories.contains(selectedCategoryForSubs)
                                  ? selectedCategoryForSubs
                                  : categories.first,
                              decoration: const InputDecoration(
                                labelText: "Parent Category",
                                border: OutlineInputBorder(),
                              ),
                              items: categories
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) async {
                                setState(() {
                                  selectedCategoryForSubs = v;
                                  activeSubcategories = [];
                                });
                                var fetched = await DBHelper.getSubcategories(
                                  v!,
                                );
                                setState(() {
                                  activeSubcategories = fetched;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            activeSubcategories.isEmpty
                                ? const Text(
                                    'No subcategories under this track.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: activeSubcategories
                                        .map(
                                          (s) => Chip(
                                            label: Text(
                                              s,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            deleteIcon: const Icon(
                                              Icons.close,
                                              size: 12,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onDeleted: () async {
                                              await DBHelper.deleteSubcategory(
                                                selectedCategoryForSubs!,
                                                s,
                                              );
                                              _load();
                                            },
                                          ),
                                        )
                                        .toList(),
                                  ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _subCtl,
                                    decoration: InputDecoration(
                                      hintText:
                                          'New subcategory for $selectedCategoryForSubs',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () async {
                                    if (_subCtl.text.trim().isNotEmpty &&
                                        selectedCategoryForSubs != null) {
                                      await DBHelper.insertSubcategory(
                                        selectedCategoryForSubs!,
                                        _subCtl.text.trim(),
                                      );
                                      _subCtl.clear();
                                      _load();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // PANEL 3: DRAGGABLE HIERARCHY WITH TIMELINE ANCHORS
          Card(
            color: Colors.grey[900],
            child: ExpansionTile(
              leading: const Icon(Icons.low_priority, color: Colors.blueAccent),
              title: const Text(
                'Urgencies Hierarchy',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Drag your custom tiers relative to system chronological timestamps.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: unifiedUrgencies.length * 52.0,
                        child: ReorderableListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: unifiedUrgencies.length,
                          // NEW: Built-in instant-grab configuration
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final u = unifiedUrgencies[index];
                            final bool isAnchor = _chronoAnchors.contains(u);

                            return ListTile(
                              key: ValueKey('urg_$u'),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              tileColor: isAnchor
                                  ? Colors.blueGrey.withValues(alpha: 0.15)
                                  : null,
                              leading: CircleAvatar(
                                backgroundColor: isAnchor
                                    ? Colors.blueAccent
                                    : Colors.blueGrey[850],
                                radius: 11,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                u,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isAnchor
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isAnchor
                                      ? Colors.blueAccent
                                      : Colors.white,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isAnchor)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        await DBHelper.deleteUrgency(u);
                                        _load();
                                      },
                                    ),
                                  // FIXED: Wrap the listener in a premium raw pointer behavior interceptor
                                  Listener(
                                    behavior: HitTestBehavior.opaque,
                                    onPointerDown: (_) {
                                      // Explicitly focus primary node instantly upon touch boundary registration
                                      FocusScope.of(context).unfocus();
                                    },
                                    child: ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          12,
                                          14,
                                          4,
                                          14,
                                        ), // Expanded touch canvas
                                        child: Icon(
                                          Icons.drag_handle,
                                          color: Colors
                                              .blueAccent, // Color indicator update for premium feedback
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          onReorderItem: (oldIndex, newIndex) {
                            setState(() {
                              final item = unifiedUrgencies.removeAt(oldIndex);
                              unifiedUrgencies.insert(newIndex, item);
                            });
                            _updateUrgencyOrder();
                          },
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _urgCtl,
                              decoration: const InputDecoration(
                                hintText: 'Add custom urgency ranking tier...',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.playlist_add,
                              color: Colors.amber,
                              size: 26,
                            ),
                            onPressed: () async {
                              if (_urgCtl.text.trim().isNotEmpty) {
                                String cleanText = _urgCtl.text.trim();
                                if (!_chronoAnchors.contains(cleanText)) {
                                  await DBHelper.insertUrgency(
                                    cleanText,
                                    unifiedUrgencies.length,
                                  );
                                  _urgCtl.clear();
                                  _load();
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
