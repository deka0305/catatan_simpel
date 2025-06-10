import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models.dart';

class ViewNotePage extends StatefulWidget {
  final Note note;
  final bool isEditing; // Tambahkan ini
  const ViewNotePage(
      {super.key, required this.note, this.isEditing = false}); // Ubah ini

  @override
  State<ViewNotePage> createState() => _ViewNotePageState();
}

class _ViewNotePageState extends State<ViewNotePage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late bool _isEditing; // Ubah jadi late

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _isEditing = widget.isEditing; // Inisialisasi dari parameter
  }

  void _saveEdit() async {
    if (_titleController.text.isNotEmpty ||
        _contentController.text.isNotEmpty) {
      await DatabaseHelper.instance.updateNote(
        Note(
          id: widget.note.id,
          title: _titleController.text,
          content: _contentController.text,
          folderId: widget.note.folderId,
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
        title: _isEditing
            ? const Text('Edit Catatan')
            : const Text('Detail Catatan'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveEdit,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
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
              enabled: _isEditing,
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
            if (_isEditing) ...[
              Row(
                children: [
                  IconButton(
                    tooltip: 'Ceklis',
                    icon: const Icon(Icons.check_box_outlined,
                        color: Color(0xFFF4B41A)),
                    onPressed: () => _insertSymbol('✔ '),
                  ),
                  IconButton(
                    tooltip: 'Bullet',
                    icon: const Icon(Icons.circle,
                        size: 18, color: Color(0xFFF4B41A)),
                    onPressed: () => _insertSymbol('• '),
                  ),
                  IconButton(
                    tooltip: 'Urutan',
                    icon: const Icon(Icons.format_list_numbered,
                        color: Color(0xFFF4B41A)),
                    onPressed: () => _insertNumberedList(),
                  ),
                ],
              ),
            ],
            Expanded(
              child: TextField(
                controller: _contentController,
                enabled: _isEditing,
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

  void _insertSymbol(String symbol) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final newText = text.replaceRange(selection.start, selection.end, symbol);
    _contentController.text = newText;
    _contentController.selection =
        TextSelection.collapsed(offset: selection.start + symbol.length);
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
    lines[currentLineIndex] =
        prefix + line.replaceFirst(RegExp(r'^(✔ |• |\d+\. )'), '');
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
    // Hitung nomor urut berdasarkan baris sebelumnya yang sudah ada nomor
    int number = 1;
    for (int i = currentLineIndex - 1; i >= 0; i--) {
      final l = lines[i];
      final match = RegExp(r'^(\d+)\. ').firstMatch(l);
      if (match != null) {
        final n = int.tryParse(match.group(1)!);
        if (n != null) {
          number = n + 1;
          break;
        }
      }
    }
    // Jika baris sudah ada nomor, ganti dengan nomor baru
    final line = lines[currentLineIndex];
    final lineWithoutNumber = line.replaceFirst(RegExp(r'^(✔ |• |\d+\. )'), '');
    final prefix = '$number. ';
    lines[currentLineIndex] = prefix + lineWithoutNumber;
    final newText = lines.join('\n');
    // Hitung offset baru setelah prefix
    int lineStart = 0;
    for (int i = 0; i < currentLineIndex; i++) {
      lineStart += lines[i].length + 1; // +1 for \n
    }
    int newOffset = lineStart + prefix.length;
    _contentController.text = newText;
    _contentController.selection = TextSelection.collapsed(offset: newOffset);
  }
}
