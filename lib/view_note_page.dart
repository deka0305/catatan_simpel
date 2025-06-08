import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models.dart';

class ViewNotePage extends StatefulWidget {
  final Note note;
  const ViewNotePage({super.key, required this.note});

  @override
  State<ViewNotePage> createState() => _ViewNotePageState();
}

class _ViewNotePageState extends State<ViewNotePage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
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

  void _insertNumberedList() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final lines = text.substring(0, selection.start).split('\n');
    final currentLine = lines.length;
    final symbol = '$currentLine. ';
    final newText = text.replaceRange(selection.start, selection.end, symbol);
    _contentController.text = newText;
    _contentController.selection =
        TextSelection.collapsed(offset: selection.start + symbol.length);
  }
}
