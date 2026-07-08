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

  static Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'utility_todo.db');
    return openDatabase(
      path,
      version: 8,
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
        await db.execute(
          "CREATE TABLE subtasks(id INTEGER PRIMARY KEY AUTOINCREMENT, parent_id INTEGER, title TEXT, isCompleted INTEGER, FOREIGN KEY(parent_id) REFERENCES tasks(id) ON DELETE CASCADE)",
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

  static Future<int> insertTask(Task task) async {
    final db = await initDB();
    return await db.insert('tasks', task.toMap());
  }

  static Future<List<Task>> getTasks() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      orderBy: "isCompleted ASC",
    );
    return List.generate(
      maps.length,
      (i) => Task(
        id: maps[i]['id'],
        title: maps[i]['title'],
        description: maps[i]['description'] ?? '',
        category: maps[i]['category'],
        subcategory: maps[i]['subcategory'] ?? '',
        urgency: maps[i]['urgency'],
        deadline: maps[i]['deadline'],
        isRepeating: maps[i]['isRepeating'],
        repeatType: maps[i]['repeatType'],
        isCompleted: maps[i]['isCompleted'],
        syncToCalendar: maps[i]['syncToCalendar'] ?? 0,
        setNotification: maps[i]['setNotification'] ?? 0,
        setAlarm: maps[i]['setAlarm'] ?? 0,
      ),
    );
  }

  static Future<void> updateTask(Task task) async {
    final db = await initDB();
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
