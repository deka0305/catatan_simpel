import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';
import 'firebase_sync_service.dart';

class DatabaseHelper {
  static const _cloudTables = [
    'folders',
    'notes',
    'tasks',
    'kas',
    'usaha_folders',
    'usaha_kas',
  ];

  final _remoteChangeController = StreamController<void>.broadcast();
  bool _flushingOutbox = false;

  /// Dipancarkan setiap kali data lokal berubah akibat event realtime dari
  /// Firebase, supaya halaman UI bisa reload tampilannya.
  Stream<void> get onRemoteChange => _remoteChangeController.stream;

  /// Catat niat perubahan ("put"/"patch"/"delete") ke antrian lokal
  /// (sync_outbox) SEBELUM mencoba kirim ke Firebase. Kalau device sedang
  /// offline, entri ini tetap tersimpan dan otomatis di-retry nanti oleh
  /// [flushOutbox] — jadi input/update/hapus saat offline tidak pernah
  /// hilang begitu online lagi.
  Future<void> _enqueueOutbox(
      String table, int id, String op, Map<String, dynamic>? payload) async {
    await _writeOutboxRow(table, id, op, payload);
    unawaited(flushOutbox());
  }

  Future<void> _writeOutboxRow(
      String table, int id, String op, Map<String, dynamic>? payload) async {
    final db = await instance.database;
    await db.insert('sync_outbox', {
      'table_name': table,
      'record_id': id,
      'op': op,
      'payload': payload == null ? null : jsonEncode(payload),
    });
  }

  /// Coba kirim semua entri di antrian ke Firebase, secara berurutan
  /// (FIFO) supaya beberapa perubahan pada record yang sama tidak
  /// terbalik urutannya. Sebelum/terlepas dari hasil kirim ke cloud,
  /// entri yang masih pending selalu diterapkan ulang ke SQLite lokal
  /// juga — supaya snapshot dari cloud yang datang belakangan tidak
  /// menimpa balik data yang belum sempat tersinkron (mis. data yang
  /// diinput/diedit/dihapus saat offline).
  Future<void> flushOutbox() async {
    if (_flushingOutbox) return;
    _flushingOutbox = true;
    try {
      final db = await instance.database;
      final rows = await db.query('sync_outbox', orderBy: 'id ASC');
      for (final row in rows) {
        final table = row['table_name'] as String;
        final id = row['record_id'] as int;
        final op = row['op'] as String;
        final payloadStr = row['payload'] as String?;
        bool ok;
        if (op == 'delete') {
          await db.delete(table, where: 'id = ?', whereArgs: [id]);
          ok = await FirebaseSyncService.instance.tryDelete('$table/$id');
        } else {
          final payload =
              jsonDecode(payloadStr ?? '{}') as Map<String, dynamic>;
          if (op == 'patch') {
            // Payload cuma berisi field yang diubah — pakai update
            // parsial, jangan replace seluruh baris (bisa menghapus
            // kolom lain yang tidak disertakan, mis. folder_id).
            final updated = await db.update(table, payload,
                where: 'id = ?', whereArgs: [id]);
            if (updated == 0) {
              final localMap = Map<String, dynamic>.from(payload);
              localMap['id'] = id;
              await db.insert(table, localMap,
                  conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            ok = await FirebaseSyncService.instance
                .tryUpdate('$table/$id', payload);
          } else {
            final localMap = Map<String, dynamic>.from(payload);
            localMap['id'] = id;
            await db.insert(table, localMap,
                conflictAlgorithm: ConflictAlgorithm.replace);
            ok = await FirebaseSyncService.instance
                .trySet('$table/$id', payload);
          }
        }
        if (ok) {
          await db.delete('sync_outbox',
              where: 'id = ?', whereArgs: [row['id']]);
        } else {
          // Masih offline/gagal — berhenti di sini, sisanya dicoba lagi
          // nanti supaya urutan antrian tetap benar.
          break;
        }
      }
    } catch (_) {
      // Best-effort, jangan sampai flush yang gagal membuat app crash.
    } finally {
      _flushingOutbox = false;
    }
  }

  /// Terapkan event realtime ("put"/"patch") dari Firebase ke SQLite lokal.
  /// Operasi ini TIDAK memicu push balik ke Firebase (untuk mencegah loop).
  Future<void> applyCloudEvent(
      String event, String path, dynamic data) async {
    final db = await instance.database;
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    try {
      if (segments.isEmpty) {
        if (data is Map) {
          for (final table in _cloudTables) {
            if (data.containsKey(table)) {
              await _applyTableReplace(db, table, data[table]);
            }
          }
        }
      } else {
        final table = segments[0];
        if (!_cloudTables.contains(table)) return;
        if (segments.length == 1) {
          if (data == null) {
            await db.delete(table);
          } else if (data is Map || data is List) {
            await _applyTableReplace(db, table, data);
          }
        } else {
          final id = int.tryParse(segments[1]);
          if (id == null) return;
          if (data == null) {
            await db.delete(table, where: 'id = ?', whereArgs: [id]);
          } else if (data is Map) {
            final map = Map<String, dynamic>.from(data);
            map.remove('id');
            if (event == 'patch') {
              final updated = await db.update(table, map,
                  where: 'id = ?', whereArgs: [id]);
              if (updated == 0) {
                map['id'] = id;
                await db.insert(table, map,
                    conflictAlgorithm: ConflictAlgorithm.ignore);
              }
            } else {
              map['id'] = id;
              await db.insert(table, map,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      }
      await flushOutbox();
      _remoteChangeController.add(null);
    } catch (e) {
      // Best-effort: jangan sampai event realtime yang tidak terduga
      // menghentikan koneksi/stream.
    }
  }

  // Firebase Realtime Database mengembalikan node sebagai JSON Array
  // (bukan object) kalau key anak-anaknya berupa angka berurutan mulai
  // dari 0 (mis. sisa dari cara sync versi lama). Helper ini menormalkan
  // Map maupun List menjadi daftar record, dan selalu memakai field 'id'
  // di dalam record itu sendiri (bukan key/index kontainer) sebagai
  // identitas — supaya tidak salah pasang saat bentuknya array.
  Future<void> _applyTableReplace(
      Database db, String table, dynamic tableData) async {
    final Iterable<dynamic> values;
    if (tableData is Map) {
      values = tableData.values;
    } else if (tableData is List) {
      values = tableData;
    } else {
      return;
    }

    final keepIds = <int>{};
    for (final value in values) {
      if (value is! Map) continue;
      final rawId = value['id'];
      final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (id == null) continue;
      keepIds.add(id);
      final map = Map<String, dynamic>.from(value);
      map['id'] = id;
      await db.insert(table, map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    // Baris lokal yang TIDAK ada di snapshot cloud biasanya adalah data
    // yang diinput saat offline dan gagal terkirim (push gagal diam-diam,
    // tanpa retry). Push ulang ke cloud di sini, JANGAN dihapus dari
    // lokal — SQLite lokal adalah sumber data utama, snapshot cloud tidak
    // boleh menghapus data yang belum sempat tersinkron.
    final existing = await db.query(table);
    for (final row in existing) {
      final id = row['id'] as int?;
      if (id != null && !keepIds.contains(id)) {
        // Tulis ke antrian saja, JANGAN trigger flushOutbox() di sini —
        // proses merge ini masih berjalan dan akan memanggil flushOutbox()
        // sendiri di akhir (applyCloudEvent). Memicu flush di tengah loop
        // ini bikin beberapa operasi SQLite jalan bertabrakan (race) dan
        // sesekali melempar exception transient ke halaman UI.
        await _writeOutboxRow(table, id, 'put', Map<String, dynamic>.from(row));
      }
    }
  }

  // CRUD Usaha Folder

  // Insert Usaha Folder (tanpa id, untuk input baru)
  Future<int> insertUsahaFolder(String nama) async {
    final db = await instance.database;
    final id = await db.insert('usaha_folders', {'nama': nama});
    await _enqueueOutbox('usaha_folders', id, 'put', {'id': id, 'nama': nama});
    return id;
  }

  // Insert Usaha Folder dengan id (untuk restore, hindari duplikat)
  Future<int> insertUsahaFolderWithId({required int id, required String nama}) async {
    final db = await instance.database;
    final result = await db.insert(
      'usaha_folders',
      {'id': id, 'nama': nama},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _enqueueOutbox('usaha_folders', id, 'put', {'id': id, 'nama': nama});
    return result;
  }

  Future<List<Map<String, dynamic>>> getUsahaFolders() async {
    final db = await instance.database;
    return await db.query('usaha_folders', orderBy: 'id DESC');
  }

  Future<int> deleteUsahaFolder(int id) async {
    final db = await instance.database;
    final result =
        await db.delete('usaha_folders', where: 'id = ?', whereArgs: [id]);
    await _enqueueOutbox('usaha_folders', id, 'delete', null);
    return result;
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
    final map = {
      'folder_id': folderId,
      'tanggal': tanggal,
      'keterangan': keterangan,
      'nominal': nominal,
      'tipe': tipe,
    };
    final id = await db.insert('usaha_kas', map);
    await _enqueueOutbox('usaha_kas', id, 'put', {'id': id, ...map});
    return id;
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
    final map = {
      'id': id,
      'folder_id': folderId,
      'tanggal': tanggal,
      'keterangan': keterangan,
      'nominal': nominal,
      'tipe': tipe,
    };
    final result = await db.insert(
      'usaha_kas',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _enqueueOutbox('usaha_kas', id, 'put', map);
    return result;
  }

  Future<List<Map<String, dynamic>>> getUsahaKasList(int folderId) async {
    final db = await instance.database;
    return await db.query('usaha_kas',
        where: 'folder_id = ?',
        whereArgs: [folderId],
        orderBy: 'tanggal DESC');
  }

  Future<int> updateUsahaKas({
    required int id,
    required String tanggal,
    required String keterangan,
    required int nominal,
    required String tipe,
  }) async {
    final db = await instance.database;
    final map = {
      'tanggal': tanggal,
      'keterangan': keterangan,
      'nominal': nominal,
      'tipe': tipe,
    };
    final result = await db.update(
      'usaha_kas',
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _enqueueOutbox('usaha_kas', id, 'patch', map);
    return result;
  }

  Future<int> deleteUsahaKas(int id) async {
    final db = await instance.database;
    final result =
        await db.delete('usaha_kas', where: 'id = ?', whereArgs: [id]);
    await _enqueueOutbox('usaha_kas', id, 'delete', null);
    return result;
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
      version: 4, // Naikkan versi jika ada perubahan struktur
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
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS sync_outbox (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              table_name TEXT NOT NULL,
              record_id INTEGER NOT NULL,
              op TEXT NOT NULL,
              payload TEXT
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
    await db.execute('''
      CREATE TABLE sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        op TEXT NOT NULL,
        payload TEXT
      )
    ''');
  }

  // CRUD Folder
  Future<int> insertFolder(NoteFolder folder) async {
    final db = await instance.database;
    final id = await db.insert('folders', folder.toMap());
    await _enqueueOutbox('folders', id, 'put', {'id': id, 'name': folder.name});
    return id;
  }

  // Insert Folder dengan id (untuk restore, hindari duplikat/crash jika
  // sudah ada, mis. karena sudah masuk lebih dulu lewat realtime sync)
  Future<int> insertFolderWithId({required int id, required String name}) async {
    final db = await instance.database;
    final result = await db.insert(
      'folders',
      {'id': id, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _enqueueOutbox('folders', id, 'put', {'id': id, 'name': name});
    return result;
  }

  Future<List<NoteFolder>> getFolders() async {
    final db = await instance.database;
    final result = await db.query('folders');
    return result.map((e) => NoteFolder.fromMap(e)).toList();
  }

  Future<int> updateFolder(NoteFolder folder) async {
    final db = await instance.database;
    final result = await db.update('folders', folder.toMap(),
        where: 'id = ?', whereArgs: [folder.id]);
    await _enqueueOutbox(
        'folders', folder.id!, 'patch', {'name': folder.name});
    return result;
  }

  Future<int> deleteFolder(int id) async {
    final db = await instance.database;
    final result = await db.delete('folders', where: 'id = ?', whereArgs: [id]);
    await _enqueueOutbox('folders', id, 'delete', null);
    return result;
  }

  // CRUD Note
  Future<int> insertNote(Note note) async {
    final db = await instance.database;
    final id = await db.insert('notes', note.toMap());
    await _enqueueOutbox('notes', id, 'put', {
      'id': id,
      'title': note.title,
      'content': note.content,
      'folderId': note.folderId,
    });
    return id;
  }

  // Insert Note dengan id (untuk restore, hindari duplikat/crash jika sudah
  // ada, mis. karena sudah masuk lebih dulu lewat realtime sync)
  Future<int> insertNoteWithId(Note note) async {
    final db = await instance.database;
    final map = note.toMap();
    final result = await db.insert(
      'notes',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _enqueueOutbox('notes', note.id!, 'put', map);
    return result;
  }

  Future<List<Note>> getNotes(int folderId) async {
    final db = await instance.database;
    final result =
        await db.query('notes', where: 'folderId = ?', whereArgs: [folderId]);
    return result.map((e) => Note.fromMap(e)).toList();
  }

  Future<int> updateNote(Note note) async {
    final db = await instance.database;
    final result = await db
        .update('notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
    await _enqueueOutbox('notes', note.id!, 'patch', {
      'title': note.title,
      'content': note.content,
      'folderId': note.folderId,
    });
    return result;
  }

  Future<int> deleteNote(int id) async {
    final db = await instance.database;
    final result = await db.delete('notes', where: 'id = ?', whereArgs: [id]);
    await _enqueueOutbox('notes', id, 'delete', null);
    return result;
  }

  // CRUD Task
  Future<int> insertTask(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    await _enqueueOutbox('tasks', id, 'put', {
      'id': id,
      'title': task.title,
      'description': task.description,
      'isDone': task.isDone ? 1 : 0,
    });
    return id;
  }

  Future<List<Task>> getTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks');
    return result.map((e) => Task.fromMap(e)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    final result = await db
        .update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
    await _enqueueOutbox('tasks', task.id!, 'patch', {
      'title': task.title,
      'description': task.description,
      'isDone': task.isDone ? 1 : 0,
    });
    return result;
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    final result = await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await _enqueueOutbox('tasks', id, 'delete', null);
    return result;
  }

  // CRUD Kas
  Future<int> insertKas(Kas kas, {bool withId = false}) async {
    final db = await instance.database;
    final map = kas.toMap();
    int id;
    if (!withId) {
      map.remove('id'); // untuk input baru, id autoincrement
      id = await db.insert('kas', map);
      map['id'] = id;
    } else {
      // Untuk restore, insert dengan id, dan jika sudah ada, abaikan
      id = await db.insert('kas', map, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await _enqueueOutbox('kas', map['id'] as int, 'put', map);
    return id;
  }

  Future<int> updateKas(Kas kas) async {
    final db = await instance.database;
    final map = kas.toMap();
    final result =
        await db.update('kas', map, where: 'id = ?', whereArgs: [kas.id]);
    await _enqueueOutbox('kas', kas.id!, 'patch', map);
    return result;
  }

  Future<List<Kas>> getKasList() async {
    final db = await instance.database;
    final result = await db.query('kas', orderBy: 'tanggal DESC');
    return result.map((e) => Kas.fromMap(e)).toList();
  }

  Future<int> deleteKas(int id) async {
    final db = await instance.database;
    final result = await db.delete('kas', where: 'id = ?', whereArgs: [id]);
    await _enqueueOutbox('kas', id, 'delete', null);
    return result;
  }
}
