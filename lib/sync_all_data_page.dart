import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  bool _isLoading = false;
  String _status = '';

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
