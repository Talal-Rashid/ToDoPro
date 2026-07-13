import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';

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
