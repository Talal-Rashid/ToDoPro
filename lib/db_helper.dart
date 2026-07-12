import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DBHelper {
  static Future<void> updateUrgencyWeight(String name, int newWeight) async {
    final db = await initDB();
    await db.update(
      'urgencies',
      {'weight': newWeight},
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  static Future<void> updateUrgencyWeights(List<String> orderedNames, List<String> chronoAnchors) async {
    final db = await initDB();
    await db.transaction((txn) async {
      for (int i = 0; i < orderedNames.length; i++) {
        String name = orderedNames[i];
        if (chronoAnchors.contains(name)) {
          await txn.insert('urgencies', {
            'name': name,
            'weight': i,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await txn.update(
          'urgencies',
          {'weight': i},
          where: 'name = ?',
          whereArgs: [name],
        );
      }
    });
  }

  static Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'utility_todo.db');
    return openDatabase(
      path,
      version: 9, // BUMPED: Advanced relational sub-task metadata tracking
      onCreate: (db, version) async {
        await db.execute(
          "CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, description TEXT, category TEXT, subcategory TEXT, urgency TEXT, deadline TEXT, isRepeating INTEGER, repeatType TEXT, isCompleted INTEGER, syncToCalendar INTEGER, setNotification INTEGER, setAlarm INTEGER)",
        );
        await db.execute(
          "CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, category TEXT, urgency TEXT, deadline TEXT, isRepeating INTEGER, repeatType TEXT, noteType TEXT, attachmentPath TEXT)",
        );
        await db.execute(
          "CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)",
        );
        await db.execute(
          "CREATE TABLE urgencies(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, weight INTEGER)",
        );
        await db.execute(
          "CREATE TABLE subcategories(id INTEGER PRIMARY KEY AUTOINCREMENT, category_name TEXT, name TEXT, UNIQUE(category_name, name))",
        );
        // UPDATED: Primary initialization string containing metadata properties
        await db.execute(
          "CREATE TABLE subtasks(id INTEGER PRIMARY KEY AUTOINCREMENT, parent_id INTEGER, title TEXT, isCompleted INTEGER, urgency TEXT, syncToCalendar INTEGER, setNotification INTEGER, setAlarm INTEGER, repeatType TEXT, FOREIGN KEY(parent_id) REFERENCES tasks(id) ON DELETE CASCADE)",
        );

        final defaultCats = ['Work', 'Study', 'Research', 'Entertainment'];
        for (var c in defaultCats) {
          await db.insert('categories', {'name': c});
        }

        final defaultSubs = {
          'Work': ['Coding', 'Meetings', 'Emails', 'Documentation'],
          'Study': ['Math', 'Science', 'History', 'Coding Practice'],
          'Research': ['Market Trends', 'Tech Stack Eval'],
          'Entertainment': ['Movies', 'Gaming', 'Reading', 'Gym'],
        };
        defaultSubs.forEach((cat, subs) async {
          for (var sub in subs) {
            await db.insert('subcategories', {
              'category_name': cat,
              'name': sub,
            });
          }
        });

        final defaultUrg = ['Today', 'Urgent', 'Not Urgent', 'Long Term'];
        for (int i = 0; i < defaultUrg.length; i++) {
          await db.insert('urgencies', {'name': defaultUrg[i], 'weight': i});
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 6) {
          try {
            await db.execute(
              "CREATE TABLE subcategories(id INTEGER PRIMARY KEY AUTOINCREMENT, category_name TEXT, name TEXT, UNIQUE(category_name, name))",
            );
          } catch (_) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute(
              "ALTER TABLE urgencies ADD COLUMN weight INTEGER DEFAULT 99",
            );
          } catch (_) {}
        }
        if (oldVersion < 8) {
          try {
            await db.execute(
              "CREATE TABLE subtasks(id INTEGER PRIMARY KEY AUTOINCREMENT, parent_id INTEGER, title TEXT, isCompleted INTEGER, FOREIGN KEY(parent_id) REFERENCES tasks(id) ON DELETE CASCADE)",
            );
          } catch (_) {}
        }
        // NEW: Version 9 structural deployment migration schema rules
        if (oldVersion < 9) {
          try {
            await db.execute(
              "ALTER TABLE subtasks ADD COLUMN urgency TEXT DEFAULT 'Today'",
            );
            await db.execute(
              "ALTER TABLE subtasks ADD COLUMN syncToCalendar INTEGER DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE subtasks ADD COLUMN setNotification INTEGER DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE subtasks ADD COLUMN setAlarm INTEGER DEFAULT 0",
            );
            await db.execute(
              "ALTER TABLE subtasks ADD COLUMN repeatType TEXT DEFAULT 'None'",
            );
          } catch (_) {}
        }
      },
    );
  }

  // --- SUB-TASK SCHEMA OPERATIONS WRAPPERS ---

  static Future<int> insertSubTask(SubTask subTask) async {
    final db = await initDB();
    return await db.insert('subtasks', subTask.toMap());
  }

  static Future<List<SubTask>> getSubTasks(int parentId) async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query(
      'subtasks',
      where: 'parent_id = ?',
      whereArgs: [parentId],
    );
    return maps.map((m) => SubTask.fromMap(m)).toList();
  }

  static Future<void> updateSubTask(SubTask subTask) async {
    final db = await initDB();
    await db.update(
      'subtasks',
      subTask.toMap(),
      where: 'id = ?',
      whereArgs: [subTask.id],
    );

    // Parent Auto-Complete Validation Check Block
    if (subTask.isCompleted == 1) {
      final List<Map<String, dynamic>> remaining = await db.query(
        'subtasks',
        where: 'parent_id = ? AND isCompleted = 0',
        whereArgs: [subTask.parentId],
      );

      if (remaining.isEmpty) {
        await db.execute("UPDATE tasks SET isCompleted = 1 WHERE id = ?", [
          subTask.parentId,
        ]);
      }
    }
  }

  static Future<void> deleteSubTask(int id) async {
    final db = await initDB();
    await db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  // --- BASE TAXONOMY WRAPPERS ---

  static Future<List<String>> getCategories() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'name ASC',
    );
    return maps.map((m) => m['name'] as String).toList();
  }

  static Future<List<String>> getSubcategories(String categoryName) async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query(
      'subcategories',
      where: 'category_name = ?',
      whereArgs: [categoryName],
      orderBy: 'name ASC',
    );
    return maps.map((m) => m['name'] as String).toList();
  }

  static Future<List<Map<String, dynamic>>> getRawUrgencies() async {
    final db = await initDB();
    return await db.query('urgencies', orderBy: 'weight ASC');
  }

  static Future<List<String>> getUrgencies() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query(
      'urgencies',
      orderBy: 'weight ASC',
    );
    return maps.map((m) => m['name'] as String).toList();
  }

  static Future<int> getUrgencyWeight(String name) async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query(
      'urgencies',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isNotEmpty && maps.first['weight'] != null) {
      return maps.first['weight'] as int;
    }
    return 99;
  }

  static Future<int> insertCategory(String name) async {
    final db = await initDB();
    return await db.insert('categories', {
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<int> insertSubcategory(String categoryName, String name) async {
    final db = await initDB();
    return await db.insert('subcategories', {
      'category_name': categoryName,
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<int> insertUrgency(String name, int weight) async {
    final db = await initDB();
    await db.execute(
      "UPDATE urgencies SET weight = weight + 1 WHERE weight >= ?",
      [weight],
    );
    return await db.insert('urgencies', {
      'name': name,
      'weight': weight,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> deleteCategory(String name) async {
    final db = await initDB();
    await db.delete('categories', where: 'name = ?', whereArgs: [name]);
    await db.delete(
      'subcategories',
      where: 'category_name = ?',
      whereArgs: [name],
    );
  }

  static Future<void> deleteSubcategory(
    String categoryName,
    String name,
  ) async {
    final db = await initDB();
    await db.delete(
      'subcategories',
      where: 'category_name = ? AND name = ?',
      whereArgs: [categoryName, name],
    );
  }

  static Future<void> deleteUrgency(String name) async {
    final db = await initDB();
    await db.delete('urgencies', where: 'name = ?', whereArgs: [name]);
  }

  static String calculateUrgencyFromDeadline(String deadlineStr, String currentUrgency) {
    if (deadlineStr.isEmpty) {
      if (currentUrgency.startsWith('⏰')) {
        return 'Today';
      }
      return currentUrgency;
    }
    final targetDate = DateTime.tryParse(deadlineStr);
    if (targetDate == null) {
      if (currentUrgency.startsWith('⏰')) {
        return 'Today';
      }
      return currentUrgency;
    }
    final difference = targetDate.difference(DateTime.now());
    if (difference.isNegative || difference.inHours <= 6) {
      return '⏰ Within 6 Hours';
    } else if (difference.inHours <= 12) {
      return '⏰ Within 12 Hours';
    } else if (difference.inHours <= 24) {
      return '⏰ Within 24 Hours';
    } else if (difference.inDays <= 7) {
      return '⏰ Within 1 Week';
    } else if (difference.inDays <= 30) {
      return '⏰ Within 1 Month';
    }
    if (currentUrgency.startsWith('⏰')) {
      return 'Today';
    }
    return currentUrgency;
  }

  static Future<int> insertTask(Task task) async {
    final db = await initDB();
    if (task.deadline != null && task.deadline!.isNotEmpty) {
      task.urgency = calculateUrgencyFromDeadline(task.deadline!, task.urgency);
    }
    return await db.insert('tasks', task.toMap());
  }

  static Future<List<Task>> getTasks() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      orderBy: "isCompleted ASC",
    );
    List<Task> list = [];
    final now = DateTime.now();
    for (var m in maps) {
      String urgency = m['urgency'] ?? '';
      final deadline = m['deadline'];

      if (deadline != null && deadline.isNotEmpty) {
        final targetDate = DateTime.tryParse(deadline);
        if (targetDate != null) {
          final difference = targetDate.difference(now);
          String calculatedUrgency = urgency;
          if (difference.isNegative || difference.inHours <= 6) {
            calculatedUrgency = '⏰ Within 6 Hours';
          } else if (difference.inHours <= 12) {
            calculatedUrgency = '⏰ Within 12 Hours';
          } else if (difference.inHours <= 24) {
            calculatedUrgency = '⏰ Within 24 Hours';
          } else if (difference.inDays <= 7) {
            calculatedUrgency = '⏰ Within 1 Week';
          } else if (difference.inDays <= 30) {
            calculatedUrgency = '⏰ Within 1 Month';
          } else {
            if (urgency.startsWith('⏰')) {
              calculatedUrgency = 'Today';
            }
          }

          if (calculatedUrgency != urgency) {
            urgency = calculatedUrgency;
            await db.update(
              'tasks',
              {'urgency': urgency},
              where: 'id = ?',
              whereArgs: [m['id']],
            );
          }
        }
      }

      list.add(Task(
        id: m['id'],
        title: m['title'],
        description: m['description'] ?? '',
        category: m['category'],
        subcategory: m['subcategory'] ?? '',
        urgency: urgency,
        deadline: deadline,
        isRepeating: m['isRepeating'],
        repeatType: m['repeatType'],
        isCompleted: m['isCompleted'],
        syncToCalendar: m['syncToCalendar'] ?? 0,
        setNotification: m['setNotification'] ?? 0,
        setAlarm: m['setAlarm'] ?? 0,
      ));
    }
    return list;
  }

  static Future<void> updateTask(Task task) async {
    final db = await initDB();
    if (task.deadline != null && task.deadline!.isNotEmpty) {
      task.urgency = calculateUrgencyFromDeadline(task.deadline!, task.urgency);
    }
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  static Future<void> deleteTask(int id) async {
    final db = await initDB();
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> insertNote(Note note) async {
    final db = await initDB();
    return await db.insert('notes', note.toMap());
  }

  static Future<List<Note>> getNotes() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query('notes');
    return List.generate(
      maps.length,
      (i) => Note(
        id: maps[i]['id'],
        title: maps[i]['title'],
        content: maps[i]['content'] ?? '',
        category: maps[i]['category'] ?? 'Study',
        urgency: maps[i]['urgency'] ?? 'Today',
        deadline:
            (maps[i]['deadline'] == null ||
                maps[i]['deadline'].toString().trim().isEmpty)
            ? null
            : maps[i]['deadline'],
        isRepeating: maps[i]['isRepeating'] ?? 0,
        repeatType: maps[i]['repeatType'] ?? 'None',
        noteType: maps[i]['noteType'] ?? 'text',
        attachmentPath:
            (maps[i]['attachmentPath'] == null ||
                maps[i]['attachmentPath'].toString().trim().isEmpty)
            ? null
            : maps[i]['attachmentPath'],
      ),
    );
  }

  static Future<void> updateNote(Note note) async {
    final db = await initDB();
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  static Future<void> deleteNote(int id) async {
    final db = await initDB();
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
