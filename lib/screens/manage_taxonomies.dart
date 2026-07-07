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
  final TextEditingController _catCtl = TextEditingController();
  final TextEditingController _urgCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    categories = await DBHelper.getCategories();
    urgencies = await DBHelper.getUrgencies();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage Categories & Urgencies')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [
          Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: categories.map((c) => Chip(
              label: Text(c),
              onDeleted: () async { await DBHelper.deleteCategory(c); _load(); },
            )).toList(),
          ),
          Row(children: [
            Expanded(child: TextField(controller: _catCtl, decoration: InputDecoration(hintText: 'New category'))),
            IconButton(icon: Icon(Icons.add), onPressed: () async { if (_catCtl.text.trim().isNotEmpty) { await DBHelper.insertCategory(_catCtl.text.trim()); _catCtl.clear(); _load(); } }),
          ]),
          Divider(),
          Text('Urgencies', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: urgencies.map((u) => Chip(
              label: Text(u),
              onDeleted: () async { await DBHelper.deleteUrgency(u); _load(); },
            )).toList(),
          ),
          Row(children: [
            Expanded(child: TextField(controller: _urgCtl, decoration: InputDecoration(hintText: 'New urgency'))),
            IconButton(icon: Icon(Icons.add), onPressed: () async { if (_urgCtl.text.trim().isNotEmpty) { await DBHelper.insertUrgency(_urgCtl.text.trim()); _urgCtl.clear(); _load(); } }),
          ]),
        ]),
      ),
    );
  }
}
