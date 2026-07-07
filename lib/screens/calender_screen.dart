import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../db_helper.dart';
import '../models.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Task> deadlineTasks = [];
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    var data = await DBHelper.getTasks();
    setState(() {
      deadlineTasks = data.where((t) => t.deadline != null).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Deadlines")),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            focusedDay: _focusedDay,
            calendarFormat: _format,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (sel, foc) => setState(() {
              _selectedDay = sel;
              _focusedDay = foc;
            }),
            onFormatChanged: (f) => setState(() => _format = f),
            eventLoader: (day) {
              return deadlineTasks.where((t) => isSameDay(DateTime.parse(t.deadline!), day)).toList();
            },
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.5), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: deadlineTasks
                  .where((t) => _selectedDay == null || isSameDay(DateTime.parse(t.deadline!), _selectedDay))
                  .map((t) => ListTile(
                        title: Text(t.title),
                        subtitle: Text("${t.urgency} • ${t.category}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(DateFormat('MMM dd').format(DateTime.parse(t.deadline!))),
                            IconButton(
                              icon: Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                              onPressed: () => _showEditTask(t),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          )
        ],
      ),
    );
  }

  void _showEditTask(Task task) {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: InputDecoration(hintText: "Title")),
            TextField(controller: descriptionController, decoration: InputDecoration(hintText: "Description")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                task.title = titleController.text;
                task.description = descriptionController.text;
                DBHelper.updateTask(task).then((_) {
                  _fetch();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                });
              },
              child: Text("Update Deadline Info"),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}