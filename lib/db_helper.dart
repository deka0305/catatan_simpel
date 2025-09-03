import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

class DatabaseHelper {
  // CRUD Usaha Folder

  // Insert Usaha Folder (tanpa id, untuk input baru)
  Future<int> insertUsahaFolder(String nama) async {
    final db = await instance.database;
    return await db.insert('usaha_folders', {'nama': nama});
  }

  // Insert Usaha Folder dengan id (untuk restore, hindari duplikat)
  Future<int> insertUsahaFolderWithId({required int id, required String nama}) async {
    final db = await instance.database;
    return await db.insert(
      'usaha_folders',
      {'id': id, 'nama': nama},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getUsahaFolders() async {
    final db = await instance.database;
    return await db.query('usaha_folders', orderBy: 'id DESC');
  }

  Future<int> deleteUsahaFolder(int id) async {
    final db = await instance.database;
    return await db.delete('usaha_folders', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Usaha Kas

  // Insert Usaha Kas (tanpa id, untuk input baru)
  Future<int> insertUsahaKas({
    required int folderId,
    required String tanggal,
    required String keterangan,
    required int nominal,
    required String tipe,
  }) async {
    final db = await instance.database;
    return await db.insert('usaha_kas', {
      'folder_id': folderId,
      'tanggal': tanggal,
      'keterangan': keterangan,
      'nominal': nominal,
      'tipe': tipe,
    });
  }

  // Insert Usaha Kas dengan id (untuk restore, hindari duplikat)
  Future<int> insertUsahaKasWithId({
    required int id,
    required int folderId,
    required String tanggal,
    required String keterangan,
    required int nominal,
    required String tipe,
  }) async {
    final db = await instance.database;
    return await db.insert(
      'usaha_kas',
      {
        'id': id,
        'folder_id': folderId,
        'tanggal': tanggal,
        'keterangan': keterangan,
        'nominal': nominal,
        'tipe': tipe,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getUsahaKasList(int folderId) async {
    final db = await instance.database;
    return await db.query('usaha_kas',
        where: 'folder_id = ?',
        whereArgs: [folderId],
        orderBy: 'tanggal DESC');
  }

  Future<int> deleteUsahaKas(int id) async {
    final db = await instance.database;
    return await db.delete('usaha_kas', where: 'id = ?', whereArgs: [id]);
  }
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
      version: 3, // Naikkan versi jika ada perubahan struktur
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
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS usaha_folders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nama TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS usaha_kas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              folder_id INTEGER NOT NULL,
              tanggal TEXT NOT NULL,
              keterangan TEXT NOT NULL,
              nominal INTEGER NOT NULL,
              tipe TEXT NOT NULL,
              FOREIGN KEY (folder_id) REFERENCES usaha_folders(id) ON DELETE CASCADE
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
    await db.execute('''
      CREATE TABLE usaha_folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE usaha_kas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_id INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        keterangan TEXT NOT NULL,
        nominal INTEGER NOT NULL,
        tipe TEXT NOT NULL,
        FOREIGN KEY (folder_id) REFERENCES usaha_folders(id) ON DELETE CASCADE
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
