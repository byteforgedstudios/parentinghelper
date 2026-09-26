class Task {
  final int? id;
  final int childId;
  final String title;
  final bool completed;
  final String date; // yyyy-mm-dd

  Task({
    this.id,
    required this.childId,
    required this.title,
    required this.completed,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'childId': childId,
    'title': title,
    'completed': completed ? 1 : 0,
    'date': date,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'],
    childId: map['childId'],
    title: map['title'],
    completed: map['completed'] == 1,
    date: map['date'],
  );
}
