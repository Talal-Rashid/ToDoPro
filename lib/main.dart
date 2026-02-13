import 'package:flutter/material.dart';
import 'db_helper.dart'; //
import 'models.dart';   //
import 'screens/task_screen.dart';     //
import 'screens/note_screen.dart';     //
import 'screens/calender_screen.dart'; //

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(primaryColor: Colors.blueAccent),
      home: MainShell(),
    ));

class MainShell extends StatefulWidget {
  @override
  _MainShellState createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [TaskScreen(), NoteScreen(), CalendarScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.check_circle), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.notes), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Deadlines'),
        ],
      ),
    );
  }
}