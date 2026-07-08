class Task {
  int? id;
  String title;
  String description;
  String category;
  String subcategory;
  String urgency;
  String? deadline;
  int isRepeating;
  String repeatType;
  int isCompleted;
  int syncToCalendar;
  int setNotification;
  int setAlarm;

  Task({
    this.id,
    required this.title,
    this.description = '',
    required this.category,
    this.subcategory = '',
    required this.urgency,
    this.deadline,
    this.isRepeating = 0,
    this.repeatType = 'None',
    this.isCompleted = 0,
    this.syncToCalendar = 0,
    this.setNotification = 0,
    this.setAlarm = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'urgency': urgency,
      'deadline': deadline,
      'isRepeating': isRepeating,
      'repeatType': repeatType,
      'isCompleted': isCompleted,
      'syncToCalendar': syncToCalendar,
      'setNotification': setNotification,
      'setAlarm': setAlarm,
    };
  }
}

// Normalized Relational SubTask Class Object with Explicit Independent Metadata Matrix
class SubTask {
  int? id;
  int parentId;
  String title;
  int isCompleted;
  String urgency;
  int syncToCalendar;
  int setNotification;
  int setAlarm;
  String repeatType;

  SubTask({
    this.id,
    required this.parentId,
    required this.title,
    this.isCompleted = 0,
    this.urgency = 'Today',
    this.syncToCalendar = 0,
    this.setNotification = 0,
    this.setAlarm = 0,
    this.repeatType = 'None',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parent_id': parentId,
      'title': title,
      'isCompleted': isCompleted,
      'urgency': urgency,
      'syncToCalendar': syncToCalendar,
      'setNotification': setNotification,
      'setAlarm': setAlarm,
      'repeatType': repeatType,
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'],
      parentId: map['parent_id'],
      title: map['title'],
      isCompleted: map['isCompleted'] ?? 0,
      urgency: map['urgency'] ?? 'Today',
      syncToCalendar: map['syncToCalendar'] ?? 0,
      setNotification: map['setNotification'] ?? 0,
      setAlarm: map['setAlarm'] ?? 0,
      repeatType: map['repeatType'] ?? 'None',
    );
  }
}

class Note {
  int? id;
  String title;
  String content;
  String category;
  String urgency;
  String? deadline;
  int isRepeating;
  String repeatType;
  String noteType;
  String? attachmentPath;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.category = 'Study',
    this.urgency = 'Today',
    this.deadline,
    this.isRepeating = 0,
    this.repeatType = 'None',
    this.noteType = 'text',
    this.attachmentPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category,
    'urgency': urgency,
    'deadline': deadline,
    'isRepeating': isRepeating,
    'repeatType': repeatType,
    'noteType': noteType,
    'attachmentPath': attachmentPath,
  };
}
