import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'db_helper.dart';
import 'models.dart';
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

// Pastikan fungsi clearAllData sudah ada di db_helper.dart
extension DatabaseHelperClearAllExt on DatabaseHelper {
  Future<void> clearAllData() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('notes');
    await db.delete('folders');
    await db.delete('kas');
    await db.delete('usaha_kas');
    await db.delete('usaha_folders');
  }
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
  Future<void> _restoreAllDataFromCloud() async {
    setState(() {
      _isLoading = true;
      _status = 'Mengambil data dari cloud...';
    });
    try {
      final baseUrl = 'https://kas-keluarga-47d2d-default-rtdb.asia-southeast1.firebasedatabase.app';

      // Ambil data folders, notes, kas dari cloud
      final foldersRes = await http.get(Uri.parse('$baseUrl/folders.json'));
      final notesRes = await http.get(Uri.parse('$baseUrl/notes.json'));
      final kasRes = await http.get(Uri.parse('$baseUrl/kas.json'));

      // Ambil data usaha_folders dan usaha_kas dari cloud
      final usahaFoldersRes = await http.get(Uri.parse('$baseUrl/usaha_folders.json'));
      final usahaKasRes = await http.get(Uri.parse('$baseUrl/usaha_kas.json'));

      final foldersData = jsonDecode(foldersRes.body) as List?;
      final notesData = jsonDecode(notesRes.body) as List?;
      final kasData = jsonDecode(kasRes.body) as List?;

      final usahaFoldersData = jsonDecode(usahaFoldersRes.body) as List?;
      final usahaKasData = jsonDecode(usahaKasRes.body) as List?;

      // Ambil data lokal
      final localFolders = await DatabaseHelper.instance.getFolders();
      final localNotes = <Note>[];
      for (final folder in localFolders) {
        final notes = await DatabaseHelper.instance.getNotes(folder.id!);
        localNotes.addAll(notes);
      }
      final localKas = await DatabaseHelper.instance.getKasList();

      // Ambil data lokal usaha
      final localUsahaFolders = await DatabaseHelper.instance.getUsahaFolders();
      final localUsahaKas = <Map<String, dynamic>>[];
      for (final folder in localUsahaFolders) {
        final kas = await DatabaseHelper.instance.getUsahaKasList(folder['id']);
        localUsahaKas.addAll(kas);
      }

      // Helper untuk cek apakah data sudah ada di lokal (berdasarkan id)
      bool folderExists(dynamic f) => localFolders.any((lf) => lf.id == f['id']);
      bool noteExists(dynamic n) => localNotes.any((ln) => ln.id == n['id']);
      bool kasExists(dynamic k) => localKas.any((lk) => lk.id == k['id']);

      bool usahaFolderExists(dynamic f) => localUsahaFolders.any((lf) => lf['id'] == f['id']);
      bool usahaKasExists(dynamic k) => localUsahaKas.any((lk) => lk['id'] == k['id']);

      int addedFolders = 0, addedNotes = 0, addedKas = 0;
      int addedUsahaFolders = 0, addedUsahaKas = 0;

      // Insert data cloud yang belum ada di lokal
      if (foldersData != null) {
        for (var f in foldersData) {
          if (f != null && f['id'] != null && !folderExists(f)) {
            await DatabaseHelper.instance.insertFolder(NoteFolder.fromMap(f));
            addedFolders++;
          }
        }
      }
      if (notesData != null) {
        for (var n in notesData) {
          if (n != null && n['id'] != null && !noteExists(n)) {
            await DatabaseHelper.instance.insertNote(Note.fromMap(n));
            addedNotes++;
          }
        }
      }
      if (kasData != null) {
        for (var k in kasData) {
          if (k != null && k['id'] != null && !kasExists(k)) {
            await DatabaseHelper.instance.insertKas(Kas.fromMap(k), withId: true);
            addedKas++;
          }
        }
      }

      // Insert usaha_folders dan usaha_kas dari cloud (hindari duplikat, gunakan id)
      if (usahaFoldersData != null) {
        for (var f in usahaFoldersData) {
          if (f != null && f['id'] != null && !usahaFolderExists(f)) {
            await DatabaseHelper.instance.insertUsahaFolderWithId(id: f['id'], nama: f['nama']);
            addedUsahaFolders++;
          }
        }
      }
      if (usahaKasData != null) {
        for (var k in usahaKasData) {
          if (k != null && k['id'] != null && !usahaKasExists(k)) {
            await DatabaseHelper.instance.insertUsahaKasWithId(
              id: k['id'],
              folderId: k['folder_id'],
              tanggal: k['tanggal'],
              keterangan: k['keterangan'],
              nominal: k['nominal'],
              tipe: k['tipe'],
            );
            addedUsahaKas++;
          }
        }
      }

      setState(() {
        _status = 'Restore selesai!\nFolder baru: $addedFolders, Note baru: $addedNotes, Kas baru: $addedKas\nUsaha Folder baru: $addedUsahaFolders, Usaha Kas baru: $addedUsahaKas';
      });
    } catch (e) {
      setState(() {
        _status = 'Gagal restore: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  // ======================= EXPORT/IMPORT (LOCAL FILE) =======================

  Future<String> _pickDirectoryOrDefault() async {
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Pilih Folder Export');
      if (dirPath != null && dirPath.isNotEmpty) {
        return dirPath;
      }
    } catch (_) {}
    // Fallback ke documents directory
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String?> _pickSavePath({required String suggestedName, required String ext}) async {
    try {
      final loc = await fsel.getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: [fsel.XTypeGroup(label: ext.toUpperCase(), extensions: [ext])],
      );
      return loc?.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportToExcel() async {
    setState(() {
      _isLoading = true;
      _status = 'Menyiapkan file Excel...';
    });
    try {
      // Ambil semua data
      final folders = await DatabaseHelper.instance.getFolders();
      final List<Note> allNotes = [];
      for (final folder in folders) {
        final notes = await DatabaseHelper.instance.getNotes(folder.id!);
        allNotes.addAll(notes);
      }
      final kasList = await DatabaseHelper.instance.getKasList();
      final usahaFolders = await DatabaseHelper.instance.getUsahaFolders();
      final List<Map<String, dynamic>> allUsahaKas = [];
      for (final uf in usahaFolders) {
        final kas = await DatabaseHelper.instance.getUsahaKasList(uf['id']);
        allUsahaKas.addAll(kas);
      }

      final excel = Excel.createExcel();
      // Hapus sheet default jika ada
      if (excel.getDefaultSheet() != null) {
        excel.delete(excel.getDefaultSheet()!);
      }

      Sheet sheetOf(Excel excel, String name) {
        // excel['name'] will create the sheet if it doesn't exist
        if (excel.sheets.containsKey(name)) {
          return excel.sheets[name]!;
        }
        return excel[name]!;
      }

      final headerStyle = CellStyle(bold: true);

      // Folders
      final shFolders = sheetOf(excel, 'folders');
      shFolders.appendRow(['id', 'name']);
      shFolders.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final f in folders) {
        shFolders.appendRow([f.id, f.name]);
      }

      // Notes
      final shNotes = sheetOf(excel, 'notes');
      shNotes.appendRow(['id', 'title', 'content', 'folderId']);
      shNotes.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final n in allNotes) {
        shNotes.appendRow([n.id, n.title, n.content, n.folderId]);
      }

      // Tasks (jika dipakai di masa depan, dump kosong aman)
      final db = await DatabaseHelper.instance.database;
      final tasks = await db.query('tasks');
      final shTasks = sheetOf(excel, 'tasks');
      shTasks.appendRow(['id', 'title', 'description', 'isDone']);
      shTasks.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final t in tasks) {
        shTasks.appendRow([t['id'], t['title'], t['description'], t['isDone']]);
      }

      // Kas
      final shKas = sheetOf(excel, 'kas');
      shKas.appendRow(['id', 'keterangan', 'jumlah', 'isMasuk', 'tanggal']);
      shKas.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final k in kasList) {
        shKas.appendRow([k.id, k.keterangan, k.jumlah, k.isMasuk ? 1 : 0, DateFormat('yyyy-MM-dd').format(k.tanggal)]);
      }

      // Usaha Folders
      final shUF = sheetOf(excel, 'usaha_folders');
      shUF.appendRow(['id', 'nama']);
      shUF.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final uf in usahaFolders) {
        shUF.appendRow([uf['id'], uf['nama']]);
      }

      // Usaha Kas
      final shUK = sheetOf(excel, 'usaha_kas');
      shUK.appendRow(['id', 'folder_id', 'tanggal', 'keterangan', 'nominal', 'tipe']);
      shUK.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final uk in allUsahaKas) {
        shUK.appendRow([
          uk['id'],
          uk['folder_id'],
          uk['tanggal'],
          uk['keterangan'],
          uk['nominal'],
          uk['tipe'],
        ]);
      }

      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final suggested = 'catatan_simpel_export_$ts.xlsx';
      final bytesList = excel.encode()!;
      final bytes = Uint8List.fromList(bytesList);

      String? savedPath;
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          savedPath = await FlutterFileDialog.saveFile(
            params: SaveFileDialogParams(data: bytes, fileName: suggested),
          );
        } catch (_) {}
      } else {
        String? savePath = await _pickSavePath(suggestedName: suggested, ext: 'xlsx');
        savePath ??= '${(await _pickDirectoryOrDefault())}${Platform.pathSeparator}$suggested';
        final file = File(savePath);
        await file.writeAsBytes(bytes, flush: true);
        savedPath = file.path;
      }

      setState(() {
        _status = savedPath != null ? 'Export Excel berhasil:\n$savedPath' : 'Export Excel selesai';
      });
      if ((Platform.isAndroid || Platform.isIOS) && savedPath != null) {
        try { await Share.shareXFiles([XFile(savedPath)], text: 'Export Excel'); } catch (_) {}
      }
    } catch (e) {
      setState(() {
        _status = 'Gagal export Excel: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcelPickFolder() async {
    setState(() {
      _isLoading = true;
      _status = 'Menyiapkan file Excel...';
    });
    try {
      // Ambil semua data
      final folders = await DatabaseHelper.instance.getFolders();
      final List<Note> allNotes = [];
      for (final folder in folders) {
        final notes = await DatabaseHelper.instance.getNotes(folder.id!);
        allNotes.addAll(notes);
      }
      final kasList = await DatabaseHelper.instance.getKasList();
      final usahaFolders = await DatabaseHelper.instance.getUsahaFolders();
      final List<Map<String, dynamic>> allUsahaKas = [];
      for (final uf in usahaFolders) {
        final kas = await DatabaseHelper.instance.getUsahaKasList(uf['id']);
        allUsahaKas.addAll(kas);
      }

      final excel = Excel.createExcel();
      if (excel.getDefaultSheet() != null) {
        excel.delete(excel.getDefaultSheet()!);
      }
      Sheet sheetOf(Excel excel, String name) {
        if (excel.sheets.containsKey(name)) {
          return excel.sheets[name]!;
        }
        return excel[name]!;
      }
      final headerStyle = CellStyle(bold: true);

      final shFolders = sheetOf(excel, 'folders');
      shFolders.appendRow(['id', 'name']);
      shFolders.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final f in folders) {
        shFolders.appendRow([f.id, f.name]);
      }
      final shNotes = sheetOf(excel, 'notes');
      shNotes.appendRow(['id', 'title', 'content', 'folderId']);
      shNotes.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final n in allNotes) {
        shNotes.appendRow([n.id, n.title, n.content, n.folderId]);
      }
      final db = await DatabaseHelper.instance.database;
      final tasks = await db.query('tasks');
      final shTasks = sheetOf(excel, 'tasks');
      shTasks.appendRow(['id', 'title', 'description', 'isDone']);
      shTasks.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final t in tasks) {
        shTasks.appendRow([t['id'], t['title'], t['description'], t['isDone']]);
      }
      final shKas = sheetOf(excel, 'kas');
      shKas.appendRow(['id', 'keterangan', 'jumlah', 'isMasuk', 'tanggal']);
      shKas.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final k in kasList) {
        shKas.appendRow([k.id, k.keterangan, k.jumlah, k.isMasuk ? 1 : 0, DateFormat('yyyy-MM-dd').format(k.tanggal)]);
      }
      final shUF = sheetOf(excel, 'usaha_folders');
      shUF.appendRow(['id', 'nama']);
      shUF.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final uf in usahaFolders) {
        shUF.appendRow([uf['id'], uf['nama']]);
      }
      final shUK = sheetOf(excel, 'usaha_kas');
      shUK.appendRow(['id', 'folder_id', 'tanggal', 'keterangan', 'nominal', 'tipe']);
      shUK.row(0).forEach((cell) => cell?.cellStyle = headerStyle);
      for (final uk in allUsahaKas) {
        shUK.appendRow([uk['id'], uk['folder_id'], uk['tanggal'], uk['keterangan'], uk['nominal'], uk['tipe']]);
      }

      // Pilih folder (desktop). Jika tidak didukung, fallback ke metode share
      String? dirPath;
      try {
        dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Pilih Folder Tujuan Export');
      } catch (_) {
        await _exportToExcel();
        return;
      }
      if (dirPath == null || dirPath.isEmpty) {
        setState(() { _status = 'Export dibatalkan.'; });
        return;
      }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('$dirPath${Platform.pathSeparator}catatan_simpel_export_$ts.xlsx');
      final bytes = excel.encode()!;
      await file.writeAsBytes(bytes, flush: true);
      setState(() {
        _status = 'Export Excel berhasil:\n${file.path}';
      });
    } catch (e) {
      setState(() {
        _status = 'Gagal export Excel: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _q(String? s) {
    if (s == null) return 'NULL';
    // Escape single quote dengan menggandakan
    final escaped = s.replaceAll("'", "''");
    return "'" + escaped + "'";
  }

  Future<void> _exportToSql() async {
    setState(() {
      _isLoading = true;
      _status = 'Menyiapkan file SQL...';
    });
    try {
      final sb = StringBuffer();
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      sb.writeln('-- Catatan Simpel SQL Export');
      sb.writeln('-- Generated at $now');
      sb.writeln('PRAGMA foreign_keys=OFF;');
      sb.writeln('BEGIN TRANSACTION;');

      // CREATE TABLE (IF NOT EXISTS)
      sb.writeln('CREATE TABLE IF NOT EXISTS folders (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL);');
      sb.writeln('CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, content TEXT NOT NULL, folderId INTEGER, FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE);');
      sb.writeln('CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT, isDone INTEGER NOT NULL);');
      sb.writeln('CREATE TABLE IF NOT EXISTS kas (id INTEGER PRIMARY KEY AUTOINCREMENT, keterangan TEXT NOT NULL, jumlah INTEGER NOT NULL, isMasuk INTEGER NOT NULL, tanggal TEXT NOT NULL);');
      sb.writeln('CREATE TABLE IF NOT EXISTS usaha_folders (id INTEGER PRIMARY KEY AUTOINCREMENT, nama TEXT NOT NULL);');
      sb.writeln('CREATE TABLE IF NOT EXISTS usaha_kas (id INTEGER PRIMARY KEY AUTOINCREMENT, folder_id INTEGER NOT NULL, tanggal TEXT NOT NULL, keterangan TEXT NOT NULL, nominal INTEGER NOT NULL, tipe TEXT NOT NULL, FOREIGN KEY (folder_id) REFERENCES usaha_folders(id) ON DELETE CASCADE);');

      // Data
      final folders = await DatabaseHelper.instance.getFolders();
      for (final f in folders) {
        sb.writeln("INSERT INTO folders(id,name) VALUES(${f.id}, ${_q(f.name)});");
      }
      final List<Note> allNotes = [];
      for (final f in folders) {
        final notes = await DatabaseHelper.instance.getNotes(f.id!);
        allNotes.addAll(notes);
      }
      for (final n in allNotes) {
        sb.writeln("INSERT INTO notes(id,title,content,folderId) VALUES(${n.id}, ${_q(n.title)}, ${_q(n.content)}, ${n.folderId});");
      }
      final db = await DatabaseHelper.instance.database;
      final tasks = await db.query('tasks');
      for (final t in tasks) {
        sb.writeln("INSERT INTO tasks(id,title,description,isDone) VALUES(${t['id']}, ${_q(t['title']?.toString())}, ${_q(t['description']?.toString())}, ${t['isDone'] ?? 0});");
      }
      final kasList = await DatabaseHelper.instance.getKasList();
      for (final k in kasList) {
        sb.writeln("INSERT INTO kas(id,keterangan,jumlah,isMasuk,tanggal) VALUES(${k.id}, ${_q(k.keterangan)}, ${k.jumlah}, ${k.isMasuk ? 1 : 0}, ${_q(k.tanggal.toIso8601String())});");
      }
      final usahaFolders = await DatabaseHelper.instance.getUsahaFolders();
      for (final uf in usahaFolders) {
        sb.writeln("INSERT INTO usaha_folders(id,nama) VALUES(${uf['id']}, ${_q(uf['nama']?.toString())});");
      }
      for (final uf in usahaFolders) {
        final ukList = await DatabaseHelper.instance.getUsahaKasList(uf['id']);
        for (final uk in ukList) {
          sb.writeln("INSERT INTO usaha_kas(id,folder_id,tanggal,keterangan,nominal,tipe) VALUES(${uk['id']}, ${uk['folder_id']}, ${_q(uk['tanggal']?.toString())}, ${_q(uk['keterangan']?.toString())}, ${uk['nominal']}, ${_q(uk['tipe']?.toString())});");
        }
      }

      sb.writeln('COMMIT;');

      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final suggested = 'catatan_simpel_export_$ts.sql';

      String? savedPath;
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final bytes = Uint8List.fromList(utf8.encode(sb.toString()));
          savedPath = await FlutterFileDialog.saveFile(
            params: SaveFileDialogParams(data: bytes, fileName: suggested),
          );
        } catch (_) {}
      } else {
        String? savePath = await _pickSavePath(suggestedName: suggested, ext: 'sql');
        savePath ??= '${(await _pickDirectoryOrDefault())}${Platform.pathSeparator}$suggested';
        final file = File(savePath);
        await file.writeAsString(sb.toString(), flush: true);
        savedPath = file.path;
      }
      setState(() {
        _status = savedPath != null ? 'Export SQL berhasil:\n$savedPath' : 'Export SQL selesai';
      });
      if ((Platform.isAndroid || Platform.isIOS) && savedPath != null) {
        try { await Share.shareXFiles([XFile(savedPath)], text: 'Export SQL'); } catch (_) {}
      }
    } catch (e) {
      setState(() {
        _status = 'Gagal export SQL: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToSqlPickFolder() async {
    setState(() {
      _isLoading = true;
      _status = 'Menyiapkan file SQL...';
    });
    try {
      final sb = StringBuffer();
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      sb.writeln('-- Catatan Simpel SQL Export');
      sb.writeln('-- Generated at $now');
      sb.writeln('PRAGMA foreign_keys=OFF;');
      sb.writeln('BEGIN TRANSACTION;');

      sb.writeln('CREATE TABLE IF NOT EXISTS folders (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL);');
      sb.writeln('CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, content TEXT NOT NULL, folderId INTEGER, FOREIGN KEY (folderId) REFERENCES folders(id) ON DELETE CASCADE);');
      sb.writeln('CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT, isDone INTEGER NOT NULL);');
      sb.writeln('CREATE TABLE IF NOT EXISTS kas (id INTEGER PRIMARY KEY AUTOINCREMENT, keterangan TEXT NOT NULL, jumlah INTEGER NOT NULL, isMasuk INTEGER NOT NULL, tanggal TEXT NOT NULL);');
      sb.writeln('CREATE TABLE IF NOT EXISTS usaha_folders (id INTEGER PRIMARY KEY AUTOINCREMENT, nama TEXT NOT NULL);');
      sb.writeln('CREATE TABLE IF NOT EXISTS usaha_kas (id INTEGER PRIMARY KEY AUTOINCREMENT, folder_id INTEGER NOT NULL, tanggal TEXT NOT NULL, keterangan TEXT NOT NULL, nominal INTEGER NOT NULL, tipe TEXT NOT NULL, FOREIGN KEY (folder_id) REFERENCES usaha_folders(id) ON DELETE CASCADE);');

      final folders = await DatabaseHelper.instance.getFolders();
      for (final f in folders) {
        sb.writeln("INSERT INTO folders(id,name) VALUES(${f.id}, ${_q(f.name)});");
      }
      final List<Note> allNotes = [];
      for (final f in folders) {
        final notes = await DatabaseHelper.instance.getNotes(f.id!);
        allNotes.addAll(notes);
      }
      for (final n in allNotes) {
        sb.writeln("INSERT INTO notes(id,title,content,folderId) VALUES(${n.id}, ${_q(n.title)}, ${_q(n.content)}, ${n.folderId});");
      }
      final db = await DatabaseHelper.instance.database;
      final tasks = await db.query('tasks');
      for (final t in tasks) {
        sb.writeln("INSERT INTO tasks(id,title,description,isDone) VALUES(${t['id']}, ${_q(t['title']?.toString())}, ${_q(t['description']?.toString())}, ${t['isDone'] ?? 0});");
      }
      final kasList = await DatabaseHelper.instance.getKasList();
      for (final k in kasList) {
        sb.writeln("INSERT INTO kas(id,keterangan,jumlah,isMasuk,tanggal) VALUES(${k.id}, ${_q(k.keterangan)}, ${k.jumlah}, ${k.isMasuk ? 1 : 0}, ${_q(k.tanggal.toIso8601String())});");
      }
      final usahaFolders = await DatabaseHelper.instance.getUsahaFolders();
      for (final uf in usahaFolders) {
        sb.writeln("INSERT INTO usaha_folders(id,nama) VALUES(${uf['id']}, ${_q(uf['nama']?.toString())});");
      }
      for (final uf in usahaFolders) {
        final ukList = await DatabaseHelper.instance.getUsahaKasList(uf['id']);
        for (final uk in ukList) {
          sb.writeln("INSERT INTO usaha_kas(id,folder_id,tanggal,keterangan,nominal,tipe) VALUES(${uk['id']}, ${uk['folder_id']}, ${_q(uk['tanggal']?.toString())}, ${_q(uk['keterangan']?.toString())}, ${uk['nominal']}, ${_q(uk['tipe']?.toString())});");
        }
      }
      sb.writeln('COMMIT;');

      String? dirPath;
      try {
        dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Pilih Folder Tujuan Export');
      } catch (_) {
        await _exportToSql();
        return;
      }
      if (dirPath == null || dirPath.isEmpty) {
        setState(() { _status = 'Export dibatalkan.'; });
        return;
      }
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('$dirPath${Platform.pathSeparator}catatan_simpel_export_$ts.sql');
      await file.writeAsString(sb.toString(), flush: true);
      setState(() {
        _status = 'Export SQL berhasil:\n${file.path}';
      });
    } catch (e) {
      setState(() {
        _status = 'Gagal export SQL: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromSql() async {
    try {
      setState(() {
        _isLoading = true;
        _status = 'Memilih file SQL...';
      });
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['sql']);
      if (picked == null || picked.files.isEmpty) {
        setState(() {
          _status = 'Import dibatalkan.';
          _isLoading = false;
        });
        return;
      }
      final path = picked.files.single.path;
      if (path == null) {
        setState(() {
          _status = 'Gagal membaca file.';
          _isLoading = false;
        });
        return;
      }
      final content = await File(path).readAsString();

      final db = await DatabaseHelper.instance.database;
      if (_importClearOld) {
        await db.delete('notes');
        await db.delete('folders');
        await db.delete('tasks');
        await db.delete('kas');
        await db.delete('usaha_kas');
        await db.delete('usaha_folders');
      }

      // Parser sederhana: pecah berdasarkan ';' di luar string literal
      List<String> _splitSqlStatements(String sql) {
        final List<String> out = [];
        final sb = StringBuffer();
        bool inString = false;
        for (int i = 0; i < sql.length; i++) {
          final ch = sql[i];
          if (ch == "'") {
            // Jika di dalam string dan ada two single-quotes ('') maka treat sebagai literal
            if (inString && i + 1 < sql.length && sql[i + 1] == "'") {
              sb.write("''");
              i++; // skip next
              continue;
            } else {
              inString = !inString;
              sb.write(ch);
              continue;
            }
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

      final stmts = _splitSqlStatements(content);
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

      setState(() {
        _status = 'Import SQL selesai. Total statement: ${stmts.length}';
      });
    } catch (e) {
      setState(() {
        _status = 'Gagal import SQL: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncAllData() async {
    setState(() {
      _isLoading = true;
      _status = 'Mengambil data dari database lokal...';
    });
    try {
      // Ambil semua data
      final folders = await DatabaseHelper.instance.getFolders();
      final List<Note> allNotes = [];
      for (final folder in folders) {
        final notes = await DatabaseHelper.instance.getNotes(folder.id!);
        allNotes.addAll(notes);
      }
      final kasList = await DatabaseHelper.instance.getKasList();

      // Ambil semua data usaha
      final usahaFolders = await DatabaseHelper.instance.getUsahaFolders();
      final List<Map<String, dynamic>> allUsahaKas = [];
      for (final folder in usahaFolders) {
        final kas = await DatabaseHelper.instance.getUsahaKasList(folder['id']);
        allUsahaKas.addAll(kas);
      }

      // Kirim data ke Firebase Realtime Database via HTTP
      final baseUrl = 'https://kas-keluarga-47d2d-default-rtdb.asia-southeast1.firebasedatabase.app';
      final responses = <String>[];

      // Folders
      final foldersRes = await http.put(
        Uri.parse('$baseUrl/folders.json'),
        body: jsonEncode(folders.map((f) => f.toMap()).toList()),
      );
      responses.add('folders: ${foldersRes.statusCode}');

      // Notes
      final notesRes = await http.put(
        Uri.parse('$baseUrl/notes.json'),
        body: jsonEncode(allNotes.map((n) => n.toMap()).toList()),
      );
      responses.add('notes: ${notesRes.statusCode}');

      // Kas
      final kasRes = await http.put(
        Uri.parse('$baseUrl/kas.json'),
        body: jsonEncode(kasList.map((k) => k.toMap()).toList()),
      );
      responses.add('kas: ${kasRes.statusCode}');

      // Usaha Folders
      final usahaFoldersRes = await http.put(
        Uri.parse('$baseUrl/usaha_folders.json'),
        body: jsonEncode(usahaFolders),
      );
      responses.add('usaha_folders: ${usahaFoldersRes.statusCode}');

      // Usaha Kas
      final usahaKasRes = await http.put(
        Uri.parse('$baseUrl/usaha_kas.json'),
        body: jsonEncode(allUsahaKas),
      );
      responses.add('usaha_kas: ${usahaKasRes.statusCode}');

      setState(() {
        _status = 'Data berhasil dikirim ke Firebase (REST API)!\n'
            'Folder: ${folders.length}\nNote: ${allNotes.length}\nKas: ${kasList.length}\nUsaha Folder: ${usahaFolders.length}\nUsaha Kas: ${allUsahaKas.length}\n'
            'Status: ${responses.join(', ')}';
      });
    } catch (e) {
      setState(() {
        _status = 'Gagal sinkronisasi: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinkronisasi Semua Data'),
        backgroundColor: const Color(0xFF143D59),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4B41A),
                      foregroundColor: const Color(0xFF143D59),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isLoading ? null : _syncAllData,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Restore dari Cloud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF143D59),
                      foregroundColor: const Color(0xFFF4B41A),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.table_view),
                  label: const Text('Export Excel (.xlsx)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4B41A),
                    foregroundColor: const Color(0xFF143D59),
                  ),
                  onPressed: _isLoading ? null : _exportToExcel,
                ),
                if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Export Excel (Pilih Folder)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4B41A),
                      foregroundColor: const Color(0xFF143D59),
                    ),
                    onPressed: _isLoading ? null : _exportToExcelPickFolder,
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.data_object),
                  label: const Text('Export SQL (.sql)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF143D59),
                    foregroundColor: const Color(0xFFF4B41A),
                  ),
                  onPressed: _isLoading ? null : _exportToSql,
                ),
                if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS))
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Export SQL (Pilih Folder)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF143D59),
                      foregroundColor: const Color(0xFFF4B41A),
                    ),
                    onPressed: _isLoading ? null : _exportToSqlPickFolder,
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import SQL (.sql)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading ? null : _importFromSql,
                ),
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
