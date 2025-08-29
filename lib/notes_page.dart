import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'db_helper.dart';
import 'models.dart';
import 'add_note_page.dart';
import 'view_note_page.dart';
import 'sync_all_data_page.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final Set<int> pinnedNoteIds = {};

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _searchController.addListener(() {
      if (!mounted) return;
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

  void _ensureValidSelectedFolder() {
    if (folders.isEmpty) {
      selectedFolderId = null;
      return;
    }
    if (selectedFolderId == null || !folders.any((f) => f.id == selectedFolderId)) {
      selectedFolderId = folders.first.id;
    }
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
    try {
      if (mounted) setState(() { _loading = true; _error = null; });
      folders = await DatabaseHelper.instance.getFolders();
      _ensureValidSelectedFolder();
      if (selectedFolderId != null) {
        await _loadNotes();
      }
    } catch (e) {
      _error = 'Gagal memuat folder: $e';
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _loadNotes() async {
    try {
      if (selectedFolderId != null) {
        notes = await DatabaseHelper.instance.getNotes(selectedFolderId!);
      } else {
        notes = [];
      }
    } catch (e) {
      _error = 'Gagal memuat catatan: $e';
    } finally {
      if (mounted) setState(() {});
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
          decoration: const InputDecoration(hintText: 'Nama Folder'),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await DatabaseHelper.instance.insertFolder(NoteFolder(name: name));
                if (mounted) Navigator.pop(context);
                await _loadFolders();
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _goToSyncAllDataPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SyncAllDataPage()),
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
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) => v < min ? min : (v > max ? max : v);
    final horizontal = clamp(w * 0.04, 12, 24);
    final left = clamp(w * 0.03, 10, 20);
    final right = clamp(w * 0.02, 8, 16);
    final minHeight = 48.0; // nyaman di HP
    final fontSize = clamp(w * 0.038, 14, 18);
    final iconSize = clamp(w * 0.045, 20, 24);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan'),
        backgroundColor: const Color(0xFF143D59),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Sinkronisasi Data',
            onPressed: _goToSyncAllDataPage,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),

                // ===================== TOP CONTROLS (FIXED) =====================
                SizedBox(
                  height: 56, // pastikan tidak infinite height
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // DROPDOWN
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 8),
                          margin: EdgeInsets.only(top: 12, left: left, right: 8, bottom: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4B41A),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(minHeight: minHeight),
                          child: (folders.isEmpty)
                              ? Row(
                                  children: const [
                                    Icon(Icons.folder_open, color: Color(0xFF143D59)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Belum ada folder — ketuk ikon folder +',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF143D59)),
                                      ),
                                    ),
                                  ],
                                )
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: folders.any((f) => f.id == selectedFolderId) ? selectedFolderId : null,
                                    hint: const Text('Pilih Folder'),
                                    borderRadius: BorderRadius.circular(10),
                                    dropdownColor: const Color(0xFFFFF5E4),
                                    isDense: true,
                                    isExpanded: true,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF143D59),
                                      fontSize: fontSize,
                                    ),
                                    icon: Icon(Icons.keyboard_arrow_down, color: const Color(0xFF143D59), size: iconSize),
                                    items: folders
                                        .map((f) => DropdownMenuItem<int>(
                                              value: f.id,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.folder, color: const Color(0xFF143D59), size: iconSize - 2),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      f.name,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (id) async {
                                      setState(() => selectedFolderId = id);
                                      await _loadNotes();
                                    },
                                  ),
                                ),
                        ),
                      ),

                      // ACTION BUTTONS
                      Container(
                        margin: EdgeInsets.only(top: 12, right: right, bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF143D59),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _addFolder,
                              icon: const Icon(Icons.create_new_folder, color: Colors.white),
                              tooltip: 'Buat Folder',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            if (selectedFolderId != null)
                              IconButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Hapus Folder'),
                                      content: const Text('Yakin ingin menghapus folder beserta seluruh catatan di dalamnya?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Batal'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await DatabaseHelper.instance.deleteFolder(selectedFolderId!);
                                    selectedFolderId = null;
                                    await _loadFolders();
                                  }
                                },
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: 'Hapus Folder',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // =================== END TOP CONTROLS (FIXED) ===================

                // SEARCH
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: left + 2, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari catatan...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFFFF5E4),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // LIST
                Expanded(
                  child: _filteredNotes().isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          itemCount: _filteredNotes().length,
                          separatorBuilder: (context, i) => Padding(
                            padding: EdgeInsets.symmetric(horizontal: left + 4),
                            child: const Divider(
                              color: Color(0xFFF4B41A),
                              thickness: 1.2,
                              height: 8,
                            ),
                          ),
                          itemBuilder: (context, i) {
                            final note = _filteredNotes()[i];
                            final isPinned = pinnedNoteIds.contains(note.id);
                            return Dismissible(
                              key: ValueKey(note.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF143D59),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white, size: 28),
                              ),
                              onDismissed: (direction) async {
                                await DatabaseHelper.instance.deleteNote(note.id!);
                                await _loadNotes();
                              },
                              child: Card(
                                color: isPinned ? const Color(0xFFFFE082) : const Color(0xFFFFF5E4),
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFF4B41A),
                                    child: Icon(Icons.notes, color: Color(0xFF143D59)),
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
                                          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                          color: const Color(0xFFF4B41A),
                                          size: 20,
                                        ),
                                        tooltip: isPinned ? 'Unpin' : 'Pin',
                                        onPressed: () => _togglePin(note),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    note.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Color(0xFFB0A295)),
                                  ),
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ViewNotePage(note: note, isEditing: true),
                                      ),
                                    );
                                    if (result == true) {
                                      await _loadNotes();
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

            // FAB
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
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.sticky_note_2_outlined, size: 64, color: Color(0xFF143D59)),
          SizedBox(height: 12),
          Text(
            'Belum ada catatan',
            style: TextStyle(
              color: Color(0xFFB0A295),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
