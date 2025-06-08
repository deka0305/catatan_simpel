// Model untuk Folder Catatan
class NoteFolder {
  int? id;
  String name;

  NoteFolder({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory NoteFolder.fromMap(Map<String, dynamic> map) {
    return NoteFolder(
      id: map['id'],
      name: map['name'],
    );
  }
}

// Model untuk Catatan
class Note {
  int? id;
  String title;
  String content;
  int folderId;

  Note(
      {this.id,
      required this.title,
      required this.content,
      required this.folderId});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'folderId': folderId,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      folderId: map['folderId'],
    );
  }
}

// Model untuk Tugas
class Task {
  int? id;
  String title;
  String description;
  bool isDone;

  Task(
      {this.id,
      required this.title,
      required this.description,
      this.isDone = false});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isDone': isDone ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      isDone: map['isDone'] == 1,
    );
  }
}
