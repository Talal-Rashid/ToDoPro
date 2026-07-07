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

    // Set a default selected category if none is active yet to ensure visibility
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
      appBar: AppBar(title: const Text('Manage Settings & Taxonomies')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. CATEGORIES MANAGEMENT
          const Text(
            'Categories Pool',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 8),
          categories.isEmpty
              ? const Text(
                  'No categories found.',
                  style: TextStyle(color: Colors.grey),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: categories
                      .map(
                        (c) => Chip(
                          label: Text(c),
                          backgroundColor: Colors.grey[900],
                          onDeleted: () async {
                            await DBHelper.deleteCategory(c);
                            if (selectedCategoryForSubs == c)
                              selectedCategoryForSubs = null;
                            _load();
                          },
                        ),
                      )
                      .toList(),
                ),
          const SizedBox(height: 8),
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
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                onPressed: () async {
                  if (_catCtl.text.trim().isNotEmpty) {
                    await DBHelper.insertCategory(_catCtl.text.trim());
                    selectedCategoryForSubs = _catCtl.text.trim();
                    _catCtl.clear();
                    _load();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 2. RELATIONAL SUBCATEGORIES MANAGEMENT (ALWAYS ACCESSIBLE VIA DROPDOWN SELECTOR)
          const Text(
            'Subcategories Engine',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const Text(
              'Create a category first to activate subcategories.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            )
          else ...[
            DropdownButtonFormField<String>(
              value: categories.contains(selectedCategoryForSubs)
                  ? selectedCategoryForSubs
                  : categories.first,
              decoration: const InputDecoration(
                labelText: "Select Parent Category to Manage",
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  selectedCategoryForSubs = v;
                  activeSubcategories = [];
                });
                var fetched = await DBHelper.getSubcategories(v!);
                setState(() {
                  activeSubcategories = fetched;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Active Subcategories under "${selectedCategoryForSubs ?? ""}"',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            activeSubcategories.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No subcategories registered under this track yet.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: activeSubcategories
                        .map(
                          (s) => Chip(
                            label: Text(s),
                            deleteIcon: const Icon(Icons.close, size: 14),
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
                          'New subcategory for ${selectedCategoryForSubs ?? ""}',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blueAccent),
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
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // 3. DRAGGABLE PRIORITY HIERARCHY MANAGEMENT
          const Text(
            'Urgencies Hierarchy (Drag to Sort Priority)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Items at the top take compilation priority in your list splits.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: urgencies.length * 56.0,
            child: ReorderableListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: urgencies.length,
              itemBuilder: (context, index) {
                final u = urgencies[index];
                return ListTile(
                  key: ValueKey('urg_$u'),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey[800],
                    radius: 14,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(u),
                  trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
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
                    hintText: 'Add custom urgency ranking tier...',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.playlist_add,
                  color: Colors.amber,
                  size: 28,
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
