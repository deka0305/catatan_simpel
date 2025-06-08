import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models.dart';

class AddNotePage extends StatefulWidget {
  final int folderId;
  const AddNotePage({super.key, required this.folderId});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  void _saveNote() async {
    if (_titleController.text.isNotEmpty ||
        _contentController.text.isNotEmpty) {
      await DatabaseHelper.instance.insertNote(
        Note(
          title: _titleController.text,
          content: _contentController.text,
          folderId: widget.folderId,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF143D59), // Navy blue
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Catatan Baru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFFF4B41A)),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF143D59)),
              decoration: const InputDecoration(
                hintText: 'Judul',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            // Tombol simbol
            Row(
              children: [
                IconButton(
                  tooltip: 'Ceklis',
                  icon: const Icon(Icons.check_box_outlined,
                      color: Color(0xFFF4B41A)),
                  onPressed: () => _insertLinePrefix('✔ '),
                ),
                IconButton(
                  tooltip: 'Bullet',
                  icon: const Icon(Icons.circle,
                      size: 18, color: Color(0xFFF4B41A)),
                  onPressed: () => _insertLinePrefix('• '),
                ),
                IconButton(
                  tooltip: 'Urutan',
                  icon: const Icon(Icons.format_list_numbered,
                      color: Color(0xFFF4B41A)),
                  onPressed: _insertNumberedList,
                ),
              ],
            ),
            Expanded(
              child: TextField(
                controller: _contentController,
                style: const TextStyle(fontSize: 18, color: Color(0xFF143D59)),
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(hintText: 'Tulis catatan...'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _insertLinePrefix(String prefix) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final lines = text.split('\n');
    int currentLineIndex =
        text.substring(0, selection.start).split('\n').length - 1;
    if (currentLineIndex < 0 || currentLineIndex >= lines.length) return;
    final line = lines[currentLineIndex];
    if (line.startsWith(prefix)) return;
    lines[currentLineIndex] = prefix + line;
    final newText = lines.join('\n');
    int newOffset = selection.start + prefix.length;
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(offset: newOffset);
  }

  void _insertNumberedList() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final lines = text.split('\n');
    int currentLineIndex =
        text.substring(0, selection.start).split('\n').length - 1;
    if (currentLineIndex < 0 || currentLineIndex >= lines.length) return;
    final line = lines[currentLineIndex];
    // Cari nomor urut otomatis
    int number = 1;
    for (int i = 0; i < currentLineIndex; i++) {
      final l = lines[i];
      final match = RegExp(r'^(\d+)\. ').firstMatch(l);
      if (match != null) {
        final n = int.tryParse(match.group(1)!);
        if (n != null && n >= number) number = n + 1;
      }
    }
    final prefix = '$number. ';
    if (line.startsWith(prefix)) return;
    lines[currentLineIndex] = prefix + line;
    final newText = lines.join('\n');
    int newOffset = selection.start + prefix.length;
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(offset: newOffset);
  }
}
