import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DBHelper {
  static Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'utility_todo.db');
    return openDatabase(path, version: 4, onCreate: (db, version) async {
      await db.execute("CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, description TEXT, category TEXT, urgency TEXT, deadline TEXT, isRepeating INTEGER, repeatType TEXT, isCompleted INTEGER)");
      await db.execute("CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, category TEXT, urgency TEXT, deadline TEXT, isRepeating INTEGER, repeatType TEXT, noteType TEXT, attachmentPath TEXT)");
      await db.execute("CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)");
      await db.execute("CREATE TABLE urgencies(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)");
      // seed defaults
      final defaultCats = ['Work', 'Study', 'Research', 'Entertainment'];
      for (var c in defaultCats) {
        await db.insert('categories', {'name': c});
      }
      final defaultUrg = ['Today', 'Urgent', 'Not Urgent', 'Long Term'];
      for (var u in defaultUrg) {
        await db.insert('urgencies', {'name': u});
      }
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        try {
          await db.execute("ALTER TABLE notes ADD COLUMN category TEXT");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE notes ADD COLUMN urgency TEXT");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE notes ADD COLUMN deadline TEXT");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE notes ADD COLUMN isRepeating INTEGER");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE notes ADD COLUMN repeatType TEXT");
        } catch (_) {}
      }
      if (oldVersion < 3) {
        try {
          await db.execute("CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)");
        } catch (_) {}
        try {
          await db.execute("CREATE TABLE urgencies(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)");
        } catch (_) {}
        // seed defaults if tables just created
        final defaultCats = ['Work', 'Study', 'Research', 'Entertainment'];
        for (var c in defaultCats) {
          try { await db.insert('categories', {'name': c}); } catch (_) {}
        }
        final defaultUrg = ['Today', 'Urgent', 'Not Urgent', 'Long Term'];
        for (var u in defaultUrg) {
          try { await db.insert('urgencies', {'name': u}); } catch (_) {}
        }
      }
      if (oldVersion < 4) {
        try { await db.execute("ALTER TABLE notes ADD COLUMN noteType TEXT"); } catch (_) {}
        try { await db.execute("ALTER TABLE notes ADD COLUMN attachmentPath TEXT"); } catch (_) {}
      }
    });
  }

  // Categories / Urgencies helpers
  static Future<List<String>> getCategories() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query('categories', orderBy: 'name ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  static Future<List<String>> getUrgencies() async {
    final db = await initDB();
    final List<Map<String, dynamic>> maps = await db.query('urgencies', orderBy: 'id ASC');
    return maps.map((m) => m['name'] as String).toList();
  }

  static Future<int> insertCategory(String name) async {
    final db = await initDB();
    return await db.insert('categories', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<int> insertUrgency(String name) async {
    final db = await initDB();
    return await db.insert('urgencies', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> deleteCategory(String name) async {
    final db = await initDB();
    await db.delete('categories', where: 'name = ?', whereArgs: [name]);
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
    final List<Map<String, dynamic>> maps = await db.query('tasks', orderBy: "isCompleted ASC");
    return List.generate(maps.length, (i) => Task(
      id: maps[i]['id'], 
      title: maps[i]['title'], 
      description: maps[i]['description'] ?? '', 
      category: maps[i]['category'],
      urgency: maps[i]['urgency'], 
      deadline: (maps[i]['deadline'] == null || (maps[i]['deadline'] is String && maps[i]['deadline'].toString().trim().isEmpty)) ? null : maps[i]['deadline'],
      isRepeating: maps[i]['isRepeating'], 
      repeatType: maps[i]['repeatType'],
      isCompleted: maps[i]['isCompleted'],
    ));
  }

  static Future<void> updateTask(Task task) async {
    final db = await initDB();
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
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
    return List.generate(maps.length, (i) => Note(
          id: maps[i]['id'],
          title: maps[i]['title'],
          content: maps[i]['content'] ?? '',
          category: maps[i]['category'] ?? 'Study',
          urgency: maps[i]['urgency'] ?? 'Today',
          deadline: (maps[i]['deadline'] == null || (maps[i]['deadline'] is String && maps[i]['deadline'].toString().trim().isEmpty)) ? null : maps[i]['deadline'],
          isRepeating: maps[i]['isRepeating'] ?? 0,
          repeatType: maps[i]['repeatType'] ?? 'None',
          noteType: maps[i]['noteType'] ?? 'text',
          attachmentPath: (maps[i]['attachmentPath'] == null || (maps[i]['attachmentPath'] is String && maps[i]['attachmentPath'].toString().trim().isEmpty)) ? null : maps[i]['attachmentPath'],
        ));
  }

  static Future<void> updateNote(Note note) async {
    final db = await initDB();
    await db.update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  static Future<void> deleteNote(int id) async {
    final db = await initDB();
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}