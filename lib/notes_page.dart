import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';
import 'models.dart';
import 'add_note_page.dart';
import 'view_note_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<NoteFolder> folders = [];
  int? selectedFolderId;
  List<Note> notes = [];

  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();
  Set<int> pinnedNoteIds = {};

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _togglePin(Note note) {
    setState(() {
      if (pinnedNoteIds.contains(note.id)) {
        pinnedNoteIds.remove(note.id);
      } else {
        pinnedNoteIds.add(note.id!);
      }
    });
  }

  List<Note> _filteredNotes() {
    final filtered = notes.where((note) {
      final query = _searchQuery.toLowerCase();
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
    }).toList();
    // Pin diurutkan ke atas
    filtered.sort((a, b) {
      final aPinned = pinnedNoteIds.contains(a.id);
      final bPinned = pinnedNoteIds.contains(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });
    return filtered;
  }

  Future<void> _loadFolders() async {
    folders = await DatabaseHelper.instance.getFolders();
    if (folders.isNotEmpty) {
      selectedFolderId ??= folders.first.id;
      _loadNotes();
    }
    setState(() {});
  }

  Future<void> _loadNotes() async {
    if (selectedFolderId != null) {
      notes = await DatabaseHelper.instance.getNotes(selectedFolderId!);
      setState(() {});
    }
  }

  void _addFolder() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Folder'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Nama Folder')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await DatabaseHelper.instance
                    .insertFolder(NoteFolder(name: controller.text));
                Navigator.pop(context);
                _loadFolders();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _addNote() async {
    if (selectedFolderId == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNotePage(folderId: selectedFolderId!),
      ),
    );
    if (result == true) {
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    margin: const EdgeInsets.only(
                        top: 12, left: 12, right: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFFF4B41A), // Yellow
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 40),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedFolderId,
                        hint: const Text('Pilih Folder'),
                        borderRadius: BorderRadius.circular(10),
                        dropdownColor: Color(0xFFFFF5E4),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF143D59),
                            fontSize: 15),
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: Color(0xFF143D59)),
                        isDense: true,
                        items: folders
                            .map((f) => DropdownMenuItem(
                                  value: f.id,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.folder,
                                          color: Color(0xFF143D59), size: 18),
                                      SizedBox(width: 6),
                                      Text(f.name),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (id) {
                          setState(() {
                            selectedFolderId = id;
                            _loadNotes();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12, right: 12, bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF143D59), // Navy blue
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    maxHeight: 40,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _addFolder,
                        icon: const Icon(Icons.create_new_folder,
                            color: Colors.white, size: 20),
                        tooltip: 'Buat Folder',
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      if (selectedFolderId != null)
                        IconButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Hapus Folder'),
                                content: const Text(
                                    'Yakin ingin menghapus folder beserta seluruh catatan di dalamnya?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Batal'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Hapus',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await DatabaseHelper.instance
                                  .deleteFolder(selectedFolderId!);
                              selectedFolderId = null;
                              _loadFolders();
                            }
                          },
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          tooltip: 'Hapus Folder',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(hintText: 'Cari catatan...'),
              ),
            ),
            Expanded(
              child: _filteredNotes().isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 64, color: Color(0xFF143D59)),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada catatan',
                            style: TextStyle(
                                color: Color(0xFFB0A295),
                                fontSize: 18,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredNotes().length,
                      separatorBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          color: Color(0xFFF4B41A), // Yellow
                          thickness: 1.2,
                          height: 8,
                          endIndent: 0,
                          indent: 0,
                        ),
                      ),
                      itemBuilder: (context, i) {
                        final note = _filteredNotes()[i];
                        return Dismissible(
                          key: ValueKey(note.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF143D59), // Navy blue
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete,
                                color: Colors.white, size: 28),
                          ),
                          onDismissed: (direction) async {
                            await DatabaseHelper.instance.deleteNote(note.id!);
                            _loadNotes();
                          },
                          child: Card(
                            color: pinnedNoteIds.contains(note.id)
                                ? Color(0xFFFFE082)
                                : Color(0xFFFFF5E4),
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              leading: CircleAvatar(
                                backgroundColor: Color(0xFFF4B41A),
                                child:
                                    Icon(Icons.notes, color: Color(0xFF143D59)),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      note.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Color(0xFF143D59),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      pinnedNoteIds.contains(note.id)
                                          ? Icons.push_pin
                                          : Icons.push_pin_outlined,
                                      color: Color(0xFFF4B41A),
                                      size: 20,
                                    ),
                                    tooltip: pinnedNoteIds.contains(note.id)
                                        ? 'Unpin'
                                        : 'Pin',
                                    onPressed: () => _togglePin(note),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                note.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    const TextStyle(color: Color(0xFFB0A295)),
                              ),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ViewNotePage(
                                        note: note, isEditing: true),
                                  ),
                                );
                                if (result == true) {
                                  _loadNotes();
                                }
                              },
                              onLongPress: () {
                                final text = '${note.title}\n\n${note.content}';
                                Share.share(text);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            onPressed: _addNote,
            backgroundColor: const Color(0xFFF4B41A),
            foregroundColor: const Color(0xFF143D59),
            elevation: 7,
            child: const Icon(Icons.add, size: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
