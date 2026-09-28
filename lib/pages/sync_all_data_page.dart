import 'package:flutter/material.dart';
import '../services/db_helper.dart';
import '../services/firebase_sync_service.dart';
import '../models.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:file_selector/file_selector.dart' as fsel;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

const _baseUrl = FirebaseSyncService.databaseUrl;

/// Tabel yang di-export/sync beserta kolomnya (urutan kolom = urutan di
/// Excel/SQL).
const _tables = {
  'folders': ['id', 'name'],
  'notes': ['id', 'title', 'content', 'folderId'],
  'tasks': ['id', 'title', 'description', 'isDone'],
  'kas': ['id', 'keterangan', 'jumlah', 'isMasuk', 'tanggal'],
  'usaha_folders': ['id', 'nama'],
  'usaha_kas': ['id', 'folder_id', 'tanggal', 'keterangan', 'nominal', 'tipe'],
};

/// Tabel yang disinkronkan ke cloud (tasks tidak ikut).
const _cloudTables = ['folders', 'notes', 'kas', 'usaha_folders', 'usaha_kas'];

const _schemaSql = [
  'CREATE TABLE IF NOT EXISTS folders (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL);',
  'CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, content TEXT NOT NULL, folderId INTEGER, FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE);',
  'CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT, isDone INTEGER NOT NULL);',
  'CREATE TABLE IF NOT EXISTS kas (id INTEGER PRIMARY KEY AUTOINCREMENT, keterangan TEXT NOT NULL, jumlah INTEGER NOT NULL, isMasuk INTEGER NOT NULL, tanggal TEXT NOT NULL);',
  'CREATE TABLE IF NOT EXISTS usaha_folders (id INTEGER PRIMARY KEY AUTOINCREMENT, nama TEXT NOT NULL);',
  'CREATE TABLE IF NOT EXISTS usaha_kas (id INTEGER PRIMARY KEY AUTOINCREMENT, folder_id INTEGER NOT NULL, tanggal TEXT NOT NULL, keterangan TEXT NOT NULL, nominal INTEGER NOT NULL, tipe TEXT NOT NULL, FOREIGN KEY (folder_id) REFERENCES usaha_folders(id) ON DELETE CASCADE);',
];

/// Firebase Realtime Database mengembalikan node sebagai JSON array hanya
/// jika key anaknya berurutan mulai dari 0; begitu ada id yang bolong
/// (misal setelah hapus data) atau id tidak mulai dari 0, ia mengembalikan
/// JSON object (map key->record) alih-alih array. Helper ini menormalkan
/// kedua bentuk itu menjadi List<Map> supaya kode restore tidak crash.
List<Map<String, dynamic>> _asRecordList(dynamic decoded) {
  final Iterable values = decoded is Map ? decoded.values : (decoded is List ? decoded : const []);
  return values.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// Ambil semua baris dari semua tabel di [_tables].
Future<Map<String, List<Map<String, dynamic>>>> _loadAll() async {
  final db = await DatabaseHelper.instance.database;
  return {for (final t in _tables.keys) t: await db.query(t)};
}

String _q(Object? v) => v == null ? 'NULL' : "'${v.toString().replaceAll("'", "''")}'";

String _sqlValue(Object? v) => v is num ? '$v' : _q(v);

/// Pecah isi file SQL berdasarkan ';' di luar string literal.
List<String> splitSqlStatements(String sql) {
  final out = <String>[];
  final sb = StringBuffer();
  var inString = false;
  for (var i = 0; i < sql.length; i++) {
    final ch = sql[i];
    if (ch == "'") {
      // '' di dalam string = kutip literal
      if (inString && i + 1 < sql.length && sql[i + 1] == "'") {
        sb.write("''");
        i++;
        continue;
      }
      inString = !inString;
    }
    if (ch == ';' && !inString) {
      final stmt = sb.toString().trim();
      if (stmt.isNotEmpty) out.add(stmt);
      sb.clear();
    } else {
      sb.write(ch);
    }
  }
  final tail = sb.toString().trim();
  if (tail.isNotEmpty) out.add(tail);
  return out;
}

class SyncAllDataPage extends StatefulWidget {
  const SyncAllDataPage({super.key});

  @override
  State<SyncAllDataPage> createState() => _SyncAllDataPageState();
}

class _SyncAllDataPageState extends State<SyncAllDataPage> {
  bool _isLoading = false;
  String _status = '';
  bool _importClearOld = false;

  /// Jalankan [job] dengan indikator loading; pesan gagal diawali [errorPrefix].
  Future<void> _run(String startStatus, String errorPrefix, Future<String> Function() job) async {
    setState(() {
      _isLoading = true;
      _status = startStatus;
    });
    try {
      final result = await job();
      setState(() => _status = result);
    } catch (e) {
      setState(() => _status = '$errorPrefix: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreAllDataFromCloud() => _run('Mengambil data dari cloud...', 'Gagal restore', () async {
        final cloud = {
          for (final t in _cloudTables)
            t: _asRecordList(jsonDecode((await http.get(Uri.parse('$_baseUrl/$t.json'))).body)),
        };
        final local = await _loadAll();
        final added = <String, int>{};
        final dbh = DatabaseHelper.instance;

        for (final t in _cloudTables) {
          final localIds = local[t]!.map((r) => r['id']).toSet();
          var count = 0;
          for (final r in cloud[t]!) {
            if (r['id'] == null || localIds.contains(r['id'])) continue;
            switch (t) {
              case 'folders':
                await dbh.insertFolderWithId(id: r['id'], name: r['name']);
              case 'notes':
                await dbh.insertNoteWithId(Note.fromMap(r));
              case 'kas':
                await dbh.insertKas(Kas.fromMap(r), withId: true);
              case 'usaha_folders':
                await dbh.insertUsahaFolderWithId(id: r['id'], nama: r['nama']);
              case 'usaha_kas':
                await dbh.insertUsahaKasWithId(
                  id: r['id'],
                  folderId: r['folder_id'],
                  tanggal: r['tanggal'],
                  keterangan: r['keterangan'],
                  nominal: r['nominal'],
                  tipe: r['tipe'],
                );
            }
            count++;
          }
          added[t] = count;
        }

        return 'Restore selesai!\n'
            'Folder baru: ${added['folders']}, Note baru: ${added['notes']}, Kas baru: ${added['kas']}\n'
            'Usaha Folder baru: ${added['usaha_folders']}, Usaha Kas baru: ${added['usaha_kas']}';
      });

  Future<void> _syncAllData() => _run('Mengambil data dari database lokal...', 'Gagal sinkronisasi', () async {
        final data = await _loadAll();
        final responses = <String>[];
        // Semua node disimpan sebagai object keyed by id (bukan array by posisi)
        // supaya formatnya sama dengan hasil sync otomatis (FirebaseSyncService)
        // dan id tidak tertukar/berubah saat di-restore di device lain.
        for (final t in _cloudTables) {
          final res = await http.put(
            Uri.parse('$_baseUrl/$t.json'),
            body: jsonEncode({for (final r in data[t]!) '${r['id']}': r}),
          );
          responses.add('$t: ${res.statusCode}');
        }
        return 'Data berhasil dikirim ke Firebase (REST API)!\n'
            'Folder: ${data['folders']!.length}\nNote: ${data['notes']!.length}\nKas: ${data['kas']!.length}\n'
            'Usaha Folder: ${data['usaha_folders']!.length}\nUsaha Kas: ${data['usaha_kas']!.length}\n'
            'Status: ${responses.join(', ')}';
      });

  // ======================= EXPORT/IMPORT (LOCAL FILE) =======================

  Future<Uint8List> _buildExcel() async {
    final data = await _loadAll();
    final excel = Excel.createExcel();
    final headerStyle = CellStyle(bold: true);
    _tables.forEach((table, cols) {
      final sheet = excel[table];
      sheet.appendRow([...cols]);
      for (final cell in sheet.row(0)) {
        cell?.cellStyle = headerStyle;
      }
      for (final r in data[table]!) {
        sheet.appendRow(cols.map((c) {
          final v = r[c];
          if (table == 'kas' && c == 'tanggal' && v is String) {
            return DateFormat('yyyy-MM-dd').format(DateTime.parse(v));
          }
          return v;
        }).toList());
      }
    });
    return Uint8List.fromList(excel.encode()!);
  }

  Future<Uint8List> _buildSql() async {
    final data = await _loadAll();
    final sb = StringBuffer()
      ..writeln('-- Catatan Simpel SQL Export')
      ..writeln('-- Generated at ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}')
      ..writeln('PRAGMA foreign_keys=OFF;')
      ..writeln('BEGIN TRANSACTION;');
    _schemaSql.forEach(sb.writeln);
    _tables.forEach((table, cols) {
      for (final r in data[table]!) {
        sb.writeln('INSERT INTO $table(${cols.join(',')}) VALUES(${cols.map((c) => _sqlValue(r[c])).join(', ')});');
      }
    });
    sb.writeln('COMMIT;');
    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  /// Simpan [bytes] ke file: dialog simpan di mobile (lalu share), dialog
  /// save-as di desktop (fallback ke folder pilihan / Documents).
  Future<String?> _saveFile(Uint8List bytes, String ext, String label) async {
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final name = 'catatan_simpel_export_$ts.$ext';

    if (Platform.isAndroid || Platform.isIOS) {
      String? saved;
      try {
        saved = await FlutterFileDialog.saveFile(params: SaveFileDialogParams(data: bytes, fileName: name));
      } catch (_) {}
      if (saved != null) {
        try {
          await Share.shareXFiles([XFile(saved)], text: label);
        } catch (_) {}
      }
      return saved;
    }

    String? path;
    try {
      path = (await fsel.getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: [fsel.XTypeGroup(label: ext.toUpperCase(), extensions: [ext])],
      ))
          ?.path;
    } catch (_) {}
    if (path == null) {
      String? dir;
      try {
        dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Pilih Folder Export');
      } catch (_) {}
      dir = (dir == null || dir.isEmpty) ? (await getApplicationDocumentsDirectory()).path : dir;
      path = '$dir${Platform.pathSeparator}$name';
    }
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> _export(String ext, String label, Future<Uint8List> Function() build) =>
      _run('Menyiapkan file $label...', 'Gagal export $label', () async {
        final saved = await _saveFile(await build(), ext, 'Export $label');
        return saved != null ? 'Export $label berhasil:\n$saved' : 'Export $label selesai';
      });

  Future<void> _importFromSql() => _run('Memilih file SQL...', 'Gagal import SQL', () async {
        final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['sql']);
        if (picked == null || picked.files.isEmpty) return 'Import dibatalkan.';
        final path = picked.files.single.path;
        if (path == null) return 'Gagal membaca file.';
        final content = await File(path).readAsString();

        final db = await DatabaseHelper.instance.database;
        if (_importClearOld) {
          // Urutan: anak dulu baru induk.
          for (final t in ['notes', 'folders', 'tasks', 'kas', 'usaha_kas', 'usaha_folders']) {
            await db.delete(t);
          }
        }

        final stmts = splitSqlStatements(content);
        await db.execute('PRAGMA foreign_keys=OFF');
        await db.transaction((txn) async {
          for (final s in stmts) {
            try {
              await txn.execute(s);
            } catch (_) {
              // Abaikan statement yang gagal (mis. CREATE TABLE yang sudah ada)
            }
          }
        });
        return 'Import SQL selesai. Total statement: ${stmts.length}';
      });

  Widget _button(String label, IconData icon, VoidCallback onPressed, Color bg, Color fg) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: fg),
      onPressed: _isLoading ? null : onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF143D59);
    const yellow = Color(0xFFF4B41A);
    final bigButton = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinkronisasi Semua Data'),
        backgroundColor: navy,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Sinkronkan ke Cloud'),
                    style: bigButton.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(yellow),
                      foregroundColor: const WidgetStatePropertyAll(navy),
                    ),
                    onPressed: _isLoading ? null : _syncAllData,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Restore dari Cloud'),
                    style: bigButton.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(navy),
                      foregroundColor: const WidgetStatePropertyAll(yellow),
                    ),
                    onPressed: _isLoading ? null : _restoreAllDataFromCloud,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 24),
            const Text('Export/Import Lokal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _button('Export Excel (.xlsx)', Icons.table_view, () => _export('xlsx', 'Excel', _buildExcel), yellow, navy),
                _button('Export SQL (.sql)', Icons.data_object, () => _export('sql', 'SQL', _buildSql), navy, yellow),
                _button('Import SQL (.sql)', Icons.upload_file, _importFromSql, Colors.blueGrey.shade700, Colors.white),
              ],
            ),
            Row(
              children: [
                Checkbox(
                  value: _importClearOld,
                  onChanged: _isLoading ? null : (v) => setState(() => _importClearOld = v ?? false),
                ),
                const Expanded(child: Text('Hapus data lama sebelum import (overwrite)')),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading) const LinearProgressIndicator(),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(_status, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
