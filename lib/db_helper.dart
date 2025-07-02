import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('catatan_simpel.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // Jangan hapus database di produksi!
    // await deleteDatabase(path); // Untuk development/testing saja
    return await openDatabase(
      path,
      version: 2, // Naikkan versi jika ada perubahan struktur
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Buat tabel kas jika upgrade dari versi sebelumnya
          await db.execute('''
            CREATE TABLE IF NOT EXISTS kas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              keterangan TEXT NOT NULL,
              jumlah INTEGER NOT NULL,
              isMasuk INTEGER NOT NULL,
              tanggal TEXT NOT NULL
            )
          ''');
        }
        // Tambahkan migrasi lain jika ada versi lebih tinggi
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        folderId INTEGER,
        FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        isDone INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE kas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        keterangan TEXT NOT NULL,
        jumlah INTEGER NOT NULL,
        isMasuk INTEGER NOT NULL,
        tanggal TEXT NOT NULL
      )
    ''');
  }

  // CRUD Folder
  Future<int> insertFolder(NoteFolder folder) async {
    final db = await instance.database;
    return await db.insert('folders', folder.toMap());
  }

  Future<List<NoteFolder>> getFolders() async {
    final db = await instance.database;
    final result = await db.query('folders');
    return result.map((e) => NoteFolder.fromMap(e)).toList();
  }

  Future<int> updateFolder(NoteFolder folder) async {
    final db = await instance.database;
    return await db.update('folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<int> deleteFolder(int id) async {
    final db = await instance.database;
    return await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Note
  Future<int> insertNote(Note note) async {
    final db = await instance.database;
    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotes(int folderId) async {
    final db = await instance.database;
    final result =
        await db.query('notes', where: 'folderId = ?', whereArgs: [folderId]);
    return result.map((e) => Note.fromMap(e)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    return await db
        .update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Task
  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    return await db.insert('tasks', task.toMap());
  }

  Future<List<Task>> getTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks');
    return result.map((e) => Task.fromMap(e)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    return await db
        .update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Kas
  Future<int> insertKas(Kas kas, {bool withId = false}) async {
    final db = await instance.database;
    final map = kas.toMap();
    if (!withId) {
      map.remove('id'); // untuk input baru, id autoincrement
      return await db.insert('kas', map);
    } else {
      // Untuk restore, insert dengan id, dan jika sudah ada, abaikan
      return await db.insert('kas', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<int> updateKas(Kas kas) async {
    final db = await instance.database;
    return await db.update('kas', kas.toMap(), where: 'id = ?', whereArgs: [kas.id]);
  }

  Future<List<Kas>> getKasList() async {
    final db = await instance.database;
    final result = await db.query('kas', orderBy: 'tanggal DESC');
    return result.map((e) => Kas.fromMap(e)).toList();
  }

  Future<int> deleteKas(int id) async {
    final db = await instance.database;
    return await db.delete('kas', where: 'id = ?', whereArgs: [id]);
  }
}
