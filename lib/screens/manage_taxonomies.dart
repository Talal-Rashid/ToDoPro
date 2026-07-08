import 'package:flutter/material.dart';
import '../db_helper.dart';

class ManageTaxonomies extends StatefulWidget {
  const ManageTaxonomies({super.key});

  @override
  State<ManageTaxonomies> createState() => _ManageTaxonomiesState();
}

class _ManageTaxonomiesState extends State<ManageTaxonomies> {
  List<String> categories = [];
  List<String> urgencies = [];
  List<String> activeSubcategories = [];
  String? selectedCategoryForSubs;

  final TextEditingController _catCtl = TextEditingController();
  final TextEditingController _urgCtl = TextEditingController();
  final TextEditingController _subCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    categories = await DBHelper.getCategories();
    urgencies = await DBHelper.getUrgencies();

    if (selectedCategoryForSubs == null && categories.isNotEmpty) {
      selectedCategoryForSubs = categories.first;
    }

    if (selectedCategoryForSubs != null) {
      activeSubcategories = await DBHelper.getSubcategories(
        selectedCategoryForSubs!,
      );
    }
    setState(() {});
  }

  Future<void> _updateUrgencyOrder() async {
    for (int i = 0; i < urgencies.length; i++) {
      await DBHelper.updateUrgencyWeight(urgencies[i], i);
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

          // PANEL 3: DRAGGABLE HIERARCHY
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
                          'Drag items to sort compilation ranking priority.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: urgencies.length * 52.0,
                        child: ReorderableListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: urgencies.length,
                          itemBuilder: (context, index) {
                            final u = urgencies[index];
                            return ListTile(
                              key: ValueKey('urg_$u'),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueGrey[850],
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
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: const Icon(
                                Icons.drag_handle,
                                color: Colors.grey,
                                size: 20,
                              ),
                            );
                          },
                          onReorderItem: (oldIndex, newIndex) {
                            setState(() {
                              final item = urgencies.removeAt(oldIndex);
                              urgencies.insert(newIndex, item);
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
                                hintText: 'Add custom ranking tier...',
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
                                await DBHelper.insertUrgency(
                                  _urgCtl.text.trim(),
                                  urgencies.length,
                                );
                                _urgCtl.clear();
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

          // FUTURE EXPANSION SLOTS PREPARED HERE
          // Card(child: ExpansionTile(leading: Icon(Icons.dark_mode), title: Text("Appearance (Theme)"))),
          // Card(child: ExpansionTile(leading: Icon(Icons.account_circle), title: Text("Account & Cloud Sync"))),
        ],
      ),
    );
  }
}
