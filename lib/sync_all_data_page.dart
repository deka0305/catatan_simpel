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

      // Ambil data folders, notes, kas
      final foldersRes = await http.get(Uri.parse('$baseUrl/folders.json'));
      final notesRes = await http.get(Uri.parse('$baseUrl/notes.json'));
      final kasRes = await http.get(Uri.parse('$baseUrl/kas.json'));

      final foldersData = jsonDecode(foldersRes.body) as List?;
      final notesData = jsonDecode(notesRes.body) as List?;
      final kasData = jsonDecode(kasRes.body) as List?;

      // Hapus data lama
      await DatabaseHelper.instance.clearAllData();

      // Insert ke lokal
      if (foldersData != null) {
        for (var f in foldersData) {
          await DatabaseHelper.instance.insertFolder(NoteFolder.fromMap(f));
        }
      }
      if (notesData != null) {
        for (var n in notesData) {
          await DatabaseHelper.instance.insertNote(Note.fromMap(n));
        }
      }
      if (kasData != null) {
        for (var k in kasData) {
          await DatabaseHelper.instance.insertKas(Kas.fromMap(k));
        }
      }

      setState(() {
        _status = 'Restore data dari cloud berhasil!';
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

      setState(() {
        _status = 'Data berhasil dikirim ke Firebase (REST API)!\n'
            'Folder: ${folders.length}\nNote: ${allNotes.length}\nKas: ${kasList.length}\n'
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
