import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  // CRUD Usaha Folder

  // Insert Usaha Folder (tanpa id, untuk input baru)
  Future<int> insertUsahaFolder(String nama) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final uid = const Uuid().v4();
    return await db.insert('usaha_folders', {
      'nama': nama,
      'uid': uid,
      'updated_at': now,
      'deleted_at': null,
    });
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
    return await db.query('usaha_folders', where: 'deleted_at IS NULL', orderBy: 'id DESC');
  }

  Future<int> deleteUsahaFolder(int id) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.update('usaha_folders', {'deleted_at': now, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
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
    final uid = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    // ambil folder_uid
    String? folderUid;
    final fu = await db.query('usaha_folders', columns: ['uid'], where: 'id = ?', whereArgs: [folderId], limit: 1);
    if (fu.isNotEmpty) folderUid = fu.first['uid'] as String?;
    return await db.insert('usaha_kas', {
      'folder_id': folderId,
      'folder_uid': folderUid,
      'tanggal': tanggal,
      'keterangan': keterangan,
      'nominal': nominal,
      'tipe': tipe,
      'uid': uid,
      'updated_at': now,
      'deleted_at': null,
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
        where: 'folder_id = ? AND deleted_at IS NULL',
        whereArgs: [folderId],
        orderBy: 'tanggal DESC');
  }

  Future<int> deleteUsahaKas(int id) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.update('usaha_kas', {'deleted_at': now, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
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
      version: 5, // Naikkan versi jika ada perubahan struktur
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
        if (oldVersion < 5) {
          // Tambah kolom sinkronisasi aman (uid, updated_at, deleted_at, folder_uid)
          await _migrateAddSyncColumns(db);
        }
        // Tambahkan migrasi lain jika ada versi lebih tinggi
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT UNIQUE,
        name TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT UNIQUE,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        folderId INTEGER,
        folder_uid TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT UNIQUE,
        title TEXT NOT NULL,
        description TEXT,
        isDone INTEGER NOT NULL,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE kas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT UNIQUE,
        keterangan TEXT NOT NULL,
        jumlah INTEGER NOT NULL,
        isMasuk INTEGER NOT NULL,
        tanggal TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE usaha_folders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT UNIQUE,
        nama TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE usaha_kas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT UNIQUE,
        folder_id INTEGER NOT NULL,
        folder_uid TEXT,
        tanggal TEXT NOT NULL,
        keterangan TEXT NOT NULL,
        nominal INTEGER NOT NULL,
        tipe TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (folder_id) REFERENCES usaha_folders(id) ON DELETE CASCADE
      )
    ''');
    // Index untuk uid
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_folders_uid ON folders(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_uid ON notes(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_uid ON tasks(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_kas_uid ON kas(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_usaha_folders_uid ON usaha_folders(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_usaha_kas_uid ON usaha_kas(uid)');
  }

  Future<void> _migrateAddSyncColumns(Database db) async {
    Future<bool> hasColumn(String table, String column) async {
      final info = await db.rawQuery("PRAGMA table_info($table)");
      return info.any((row) => row['name'] == column);
    }
    Future<void> addColumnIfMissing(String table, String column, String type) async {
      if (!await hasColumn(table, column)) {
        await db.execute('ALTER TABLE ' + table + ' ADD COLUMN ' + column + ' ' + type);
      }
    }
    await addColumnIfMissing('folders', 'uid', 'TEXT');
    await addColumnIfMissing('folders', 'updated_at', 'TEXT');
    await addColumnIfMissing('folders', 'deleted_at', 'TEXT');

    await addColumnIfMissing('notes', 'uid', 'TEXT');
    await addColumnIfMissing('notes', 'folder_uid', 'TEXT');
    await addColumnIfMissing('notes', 'updated_at', 'TEXT');
    await addColumnIfMissing('notes', 'deleted_at', 'TEXT');

    await addColumnIfMissing('tasks', 'uid', 'TEXT');
    await addColumnIfMissing('tasks', 'updated_at', 'TEXT');
    await addColumnIfMissing('tasks', 'deleted_at', 'TEXT');

    await addColumnIfMissing('kas', 'uid', 'TEXT');
    await addColumnIfMissing('kas', 'updated_at', 'TEXT');
    await addColumnIfMissing('kas', 'deleted_at', 'TEXT');

    await addColumnIfMissing('usaha_folders', 'uid', 'TEXT');
    await addColumnIfMissing('usaha_folders', 'updated_at', 'TEXT');
    await addColumnIfMissing('usaha_folders', 'deleted_at', 'TEXT');

    await addColumnIfMissing('usaha_kas', 'uid', 'TEXT');
    await addColumnIfMissing('usaha_kas', 'folder_uid', 'TEXT');
    await addColumnIfMissing('usaha_kas', 'updated_at', 'TEXT');
    await addColumnIfMissing('usaha_kas', 'deleted_at', 'TEXT');

    // Index
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_folders_uid ON folders(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_uid ON notes(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_uid ON tasks(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_kas_uid ON kas(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_usaha_folders_uid ON usaha_folders(uid)');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_usaha_kas_uid ON usaha_kas(uid)');

    // Backfill uid & timestamps
    final now = DateTime.now().toIso8601String();
    final uuid = Uuid();

    // folders
    final folders = await db.query('folders');
    for (final f in folders) {
      if ((f['uid'] == null) || (f['uid'] as String).isEmpty) {
        await db.update('folders', {'uid': uuid.v4(), 'updated_at': now}, where: 'id = ?', whereArgs: [f['id']]);
      } else if (f['updated_at'] == null) {
        await db.update('folders', {'updated_at': now}, where: 'id = ?', whereArgs: [f['id']]);
      }
    }

    // notes
    final notes = await db.query('notes');
    for (final n in notes) {
      Map<String, Object?> patch = {};
      if ((n['uid'] == null) || (n['uid'] as String).isEmpty) {
        patch['uid'] = uuid.v4();
      }
      if (n['updated_at'] == null) patch['updated_at'] = now;
      if (n['folder_uid'] == null && n['folderId'] != null) {
        final fid = n['folderId'] as int;
        final fu = await db.query('folders', columns: ['uid'], where: 'id = ?', whereArgs: [fid]);
        if (fu.isNotEmpty && fu.first['uid'] != null) patch['folder_uid'] = fu.first['uid'];
      }
      if (patch.isNotEmpty) {
        await db.update('notes', patch, where: 'id = ?', whereArgs: [n['id']]);
      }
    }

    // tasks
    final tasks = await db.query('tasks');
    for (final t in tasks) {
      Map<String, Object?> patch = {};
      if ((t['uid'] == null) || (t['uid'] as String).isEmpty) patch['uid'] = uuid.v4();
      if (t['updated_at'] == null) patch['updated_at'] = now;
      if (patch.isNotEmpty) await db.update('tasks', patch, where: 'id = ?', whereArgs: [t['id']]);
    }

    // kas
    final kases = await db.query('kas');
    for (final k in kases) {
      Map<String, Object?> patch = {};
      if ((k['uid'] == null) || (k['uid'] as String).isEmpty) patch['uid'] = uuid.v4();
      if (k['updated_at'] == null) patch['updated_at'] = now;
      if (patch.isNotEmpty) await db.update('kas', patch, where: 'id = ?', whereArgs: [k['id']]);
    }

    // usaha_folders
    final uf = await db.query('usaha_folders');
    for (final f in uf) {
      Map<String, Object?> patch = {};
      if ((f['uid'] == null) || (f['uid'] as String).isEmpty) patch['uid'] = uuid.v4();
      if (f['updated_at'] == null) patch['updated_at'] = now;
      if (patch.isNotEmpty) await db.update('usaha_folders', patch, where: 'id = ?', whereArgs: [f['id']]);
    }

    // usaha_kas
    final uk = await db.query('usaha_kas');
    for (final e in uk) {
      Map<String, Object?> patch = {};
      if ((e['uid'] == null) || (e['uid'] as String).isEmpty) patch['uid'] = uuid.v4();
      if (e['updated_at'] == null) patch['updated_at'] = now;
      if (e['folder_uid'] == null && e['folder_id'] != null) {
        final fid = e['folder_id'] as int;
        final fu = await db.query('usaha_folders', columns: ['uid'], where: 'id = ?', whereArgs: [fid]);
        if (fu.isNotEmpty && fu.first['uid'] != null) patch['folder_uid'] = fu.first['uid'];
      }
      if (patch.isNotEmpty) await db.update('usaha_kas', patch, where: 'id = ?', whereArgs: [e['id']]);
    }
  }

  // CRUD Folder
  Future<int> insertFolder(NoteFolder folder) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final uid = const Uuid().v4();
    final map = folder.toMap();
    map['uid'] = uid;
    map['updated_at'] = now;
    map['deleted_at'] = null;
    return await db.insert('folders', map);
  }

  Future<List<NoteFolder>> getFolders() async {
    final db = await instance.database;
    final result = await db.query('folders', where: 'deleted_at IS NULL');
    return result.map((e) => NoteFolder.fromMap(e)).toList();
  }

  Future<int> updateFolder(NoteFolder folder) async {
    final db = await instance.database;
    final map = folder.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('folders', map,
        where: 'id = ?', whereArgs: [folder.id]);
  }

  Future<int> deleteFolder(int id) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.update('folders', {'deleted_at': now, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Note
  Future<int> insertNote(Note note) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final uid = const Uuid().v4();
    final map = note.toMap();
    // folder_uid
    if (map['folderId'] != null) {
      final fid = map['folderId'] as int;
      final fu = await db.query('folders', columns: ['uid'], where: 'id = ?', whereArgs: [fid], limit: 1);
      if (fu.isNotEmpty) map['folder_uid'] = fu.first['uid'];
    }
    map['uid'] = uid;
    map['updated_at'] = now;
    map['deleted_at'] = null;
    return await db.insert('notes', map);
  }

  Future<List<Note>> getNotes(int folderId) async {
    final db = await instance.database;
    final result =
        await db.query('notes', where: 'folderId = ? AND deleted_at IS NULL', whereArgs: [folderId]);
    return result.map((e) => Note.fromMap(e)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    final map = note.toMap();
    // update folder_uid if folderId changed
    if (map['folderId'] != null) {
      final fid = map['folderId'] as int;
      final fu = await db.query('folders', columns: ['uid'], where: 'id = ?', whereArgs: [fid], limit: 1);
      if (fu.isNotEmpty) map['folder_uid'] = fu.first['uid'];
    }
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db
        .update('notes', map, where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.update('notes', {'deleted_at': now, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Task
  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final uid = const Uuid().v4();
    final map = task.toMap();
    map['uid'] = uid;
    map['updated_at'] = now;
    map['deleted_at'] = null;
    return await db.insert('tasks', map);
  }

  Future<List<Task>> getTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', where: 'deleted_at IS NULL');
    return result.map((e) => Task.fromMap(e)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    final map = task.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db
        .update('tasks', map, where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.update('tasks', {'deleted_at': now, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  // CRUD Kas
  Future<int> insertKas(Kas kas, {bool withId = false}) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final map = kas.toMap();
    map['uid'] = map['uid'] ?? const Uuid().v4();
    map['updated_at'] = now;
    map['deleted_at'] = null;
    if (!withId) map.remove('id'); // untuk input baru, id autoincrement
    return await db.insert('kas', map, conflictAlgorithm: withId ? ConflictAlgorithm.ignore : null);
  }

  Future<int> updateKas(Kas kas) async {
    final db = await instance.database;
    final map = kas.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('kas', map, where: 'id = ?', whereArgs: [kas.id]);
  }

  Future<List<Kas>> getKasList() async {
    final db = await instance.database;
    final result = await db.query('kas', where: 'deleted_at IS NULL', orderBy: 'tanggal DESC');
    return result.map((e) => Kas.fromMap(e)).toList();
  }

  Future<int> deleteKas(int id) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.update('kas', {'deleted_at': now, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }

  // ===================== Upsert by UID for Sync =====================
  Future<Map<String, dynamic>?> _getByUid(String table, String uid) async {
    final db = await instance.database;
    final res = await db.query(table, where: 'uid = ?', whereArgs: [uid], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  bool _isRemoteNewer(String? localUpdatedAt, String? remoteUpdatedAt) {
    if (remoteUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;
    try {
      return DateTime.parse(remoteUpdatedAt).isAfter(DateTime.parse(localUpdatedAt));
    } catch (_) {
      return true;
    }
  }

  Future<int> upsertFolderByUid({required String uid, required String name, String? updatedAt, String? deletedAt}) async {
    final db = await instance.database;
    final local = await _getByUid('folders', uid);
    final now = DateTime.now().toIso8601String();
    if (local == null) {
      return await db.insert('folders', {
        'uid': uid,
        'name': name,
        'updated_at': updatedAt ?? now,
        'deleted_at': deletedAt,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (_isRemoteNewer(local['updated_at'] as String?, updatedAt)) {
      return await db.update('folders', {
        'name': name,
        'updated_at': updatedAt ?? now,
        'deleted_at': deletedAt,
      }, where: 'uid = ?', whereArgs: [uid]);
    }
    return 0;
  }

  Future<int> upsertNoteByUid({
    required String uid,
    required String title,
    required String content,
    String? folderUid,
    int? folderId,
    String? updatedAt,
    String? deletedAt,
  }) async {
    final db = await instance.database;
    // Resolve folderId via folderUid if provided
    int? resolvedFolderId = folderId;
    if (resolvedFolderId == null && folderUid != null) {
      final f = await _getByUid('folders', folderUid);
      resolvedFolderId = f != null ? f['id'] as int? : null;
    }
    final local = await _getByUid('notes', uid);
    final now = DateTime.now().toIso8601String();
    final row = {
      'uid': uid,
      'title': title,
      'content': content,
      'folderId': resolvedFolderId,
      'folder_uid': folderUid,
      'updated_at': updatedAt ?? now,
      'deleted_at': deletedAt,
    };
    if (local == null) {
      return await db.insert('notes', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (_isRemoteNewer(local['updated_at'] as String?, updatedAt)) {
      return await db.update('notes', row, where: 'uid = ?', whereArgs: [uid]);
    }
    return 0;
  }

  Future<int> upsertTaskByUid({
    required String uid,
    required String title,
    String? description,
    required bool isDone,
    String? updatedAt,
    String? deletedAt,
  }) async {
    final db = await instance.database;
    final local = await _getByUid('tasks', uid);
    final now = DateTime.now().toIso8601String();
    final row = {
      'uid': uid,
      'title': title,
      'description': description,
      'isDone': isDone ? 1 : 0,
      'updated_at': updatedAt ?? now,
      'deleted_at': deletedAt,
    };
    if (local == null) {
      return await db.insert('tasks', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (_isRemoteNewer(local['updated_at'] as String?, updatedAt)) {
      return await db.update('tasks', row, where: 'uid = ?', whereArgs: [uid]);
    }
    return 0;
  }

  Future<int> upsertKasByUid({
    required String uid,
    required String keterangan,
    required int jumlah,
    required bool isMasuk,
    required String tanggal,
    String? updatedAt,
    String? deletedAt,
  }) async {
    final db = await instance.database;
    final local = await _getByUid('kas', uid);
    final now = DateTime.now().toIso8601String();
    final row = {
      'uid': uid,
      'keterangan': keterangan,
      'jumlah': jumlah,
      'isMasuk': isMasuk ? 1 : 0,
      'tanggal': tanggal,
      'updated_at': updatedAt ?? now,
      'deleted_at': deletedAt,
    };
    if (local == null) {
      return await db.insert('kas', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (_isRemoteNewer(local['updated_at'] as String?, updatedAt)) {
      return await db.update('kas', row, where: 'uid = ?', whereArgs: [uid]);
    }
    return 0;
  }

  Future<int> upsertUsahaFolderByUid({required String uid, required String nama, String? updatedAt, String? deletedAt}) async {
    final db = await instance.database;
    final local = await _getByUid('usaha_folders', uid);
    final now = DateTime.now().toIso8601String();
    final row = {
      'uid': uid,
      'nama': nama,
      'updated_at': updatedAt ?? now,
      'deleted_at': deletedAt,
    };
    if (local == null) {
      return await db.insert('usaha_folders', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (_isRemoteNewer(local['updated_at'] as String?, updatedAt)) {
      return await db.update('usaha_folders', row, where: 'uid = ?', whereArgs: [uid]);
    }
    return 0;
  }

  Future<int> upsertUsahaKasByUid({
    required String uid,
    required String folderUid,
    required String tanggal,
    required String keterangan,
    required int nominal,
    required String tipe,
    String? updatedAt,
    String? deletedAt,
  }) async {
    final db = await instance.database;
    // Resolve folderId via folderUid
    int? folderId;
    final f = await _getByUid('usaha_folders', folderUid);
    folderId = f != null ? f['id'] as int? : null;
    final local = await _getByUid('usaha_kas', uid);
    final now = DateTime.now().toIso8601String();
    final row = {
      'uid': uid,
      'folder_id': folderId,
      'folder_uid': folderUid,
      'tanggal': tanggal,
      'keterangan': keterangan,
      'nominal': nominal,
      'tipe': tipe,
      'updated_at': updatedAt ?? now,
      'deleted_at': deletedAt,
    };
    if (local == null) {
      return await db.insert('usaha_kas', row, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (_isRemoteNewer(local['updated_at'] as String?, updatedAt)) {
      return await db.update('usaha_kas', row, where: 'uid = ?', whereArgs: [uid]);
    }
    return 0;
  }
}
