class Task {
  int? id;
  String title;
  String description;
  String category;
  String urgency;
  String? deadline;
  int isRepeating;
  String repeatType;
  int isCompleted;

  Task({
    this.id,
    required this.title,
    this.description = '',
    required this.category,
    required this.urgency,
    this.deadline,
    this.isRepeating = 0,
    this.repeatType = 'None',
    this.isCompleted = 0
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'urgency': urgency,
      'deadline': deadline,
      'isRepeating': isRepeating,
      'repeatType': repeatType,
      'isCompleted': isCompleted
    };
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
  String noteType; // 'text' | 'canvas' | 'photo'
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