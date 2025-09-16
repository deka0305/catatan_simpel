import 'dart:math';
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

class _NotesPageState extends State<NotesPage>
    with SingleTickerProviderStateMixin {
  List<NoteFolder> folders = [];
  int? selectedFolderId;
  List<Note> notes = [];

  late final AnimationController _cloudController;
  late final List<_CloudConfig> _clouds;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<int> pinnedNoteIds = {};

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
    final random = Random();
    _clouds = List.generate(
      5,
      (index) => _CloudConfig(
        speed: 0.8 + random.nextDouble() * 0.8,
        topFactor: 0.08 + random.nextDouble() * 0.45,
        size: 70 + random.nextDouble() * 60,
        opacity: 0.45 + random.nextDouble() * 0.4,
        phase: random.nextDouble(),
      ),
    );
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
    _cloudController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _ensureValidSelectedFolder() {
    if (folders.isEmpty) {
      selectedFolderId = null;
      return;
    }
    if (selectedFolderId == null ||
        !folders.any((f) => f.id == selectedFolderId)) {
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
      if (mounted)
        setState(() {
          _loading = true;
          _error = null;
        });
      folders = await DatabaseHelper.instance.getFolders();
      _ensureValidSelectedFolder();
      if (selectedFolderId != null) {
        await _loadNotes();
      }
    } catch (e) {
      _error = 'Gagal memuat folder: $e';
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
        });
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
                await DatabaseHelper.instance
                    .insertFolder(NoteFolder(name: name));
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

  PreferredSizeWidget _buildAnimatedAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(150),
      child: AnimatedBuilder(
        animation: _cloudController,
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F4C75), Color(0xFF3E92CC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x400F4C75),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -32,
                      right: -24,
                      child: IgnorePointer(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFE082), Color(0xFFFFC046)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final cloud in _clouds)
                      Positioned(
                        left: ((cloud.phase +
                                        _cloudController.value * cloud.speed) %
                                    1) *
                                (width + cloud.size) -
                            cloud.size,
                        top: height * cloud.topFactor,
                        child: Opacity(
                          opacity: cloud.opacity,
                          child: Icon(
                            Icons.cloud_rounded,
                            size: cloud.size,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ClipPath(
                        clipper: _AppBarWaveClipper(),
                        child: Container(
                          height: height * 0.4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.22),
                                Colors.white.withOpacity(0.08),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Catatan',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Catatan pentingmu tertata rapi',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Material(
                              color: Colors.white24,
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.cloud_sync,
                                    color: Colors.white),
                                tooltip: 'Sinkronisasi Data',
                                onPressed: _goToSyncAllDataPage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    double clamp(double v, double min, double max) =>
        v < min ? min : (v > max ? max : v);
    final horizontal = clamp(w * 0.04, 12, 24);
    final left = clamp(w * 0.03, 10, 20);
    final right = clamp(w * 0.02, 8, 16);
    final minHeight = 48.0; // nyaman di HP
    final fontSize = clamp(w * 0.038, 14, 18);
    final iconSize = clamp(w * 0.045, 20, 24);
    final filteredNotes = _filteredNotes();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: _buildAnimatedAppBar(),
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF7F8FB), Color(0xFFFFFBF5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -60,
              right: -40,
              child: IgnorePointer(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF4B41A).withOpacity(0.18),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -50,
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF143D59).withOpacity(0.12),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.red))),
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
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontal, vertical: 8),
                          margin: EdgeInsets.only(
                              top: 12, left: left, right: 8, bottom: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE0B2), Color(0xFFFFF5E4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFF4B41A).withOpacity(0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(minHeight: minHeight),
                          child: (folders.isEmpty)
                              ? Row(
                                  children: const [
                                    Icon(Icons.folder_open,
                                        color: Color(0xFF143D59)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Belum ada folder - ketuk ikon folder +',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF143D59)),
                                      ),
                                    ),
                                  ],
                                )
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: folders.any(
                                            (f) => f.id == selectedFolderId)
                                        ? selectedFolderId
                                        : null,
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
                                    icon: Icon(Icons.keyboard_arrow_down,
                                        color: const Color(0xFF143D59),
                                        size: iconSize),
                                    items: folders
                                        .map((f) => DropdownMenuItem<int>(
                                              value: f.id,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.folder,
                                                      color: const Color(
                                                          0xFF143D59),
                                                      size: iconSize - 2),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      f.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                        margin:
                            EdgeInsets.only(top: 12, right: right, bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F4C75), Color(0xFF143D59)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _addFolder,
                              icon: const Icon(Icons.create_new_folder,
                                  color: Colors.white),
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
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await DatabaseHelper.instance
                                        .deleteFolder(selectedFolderId!);
                                    selectedFolderId = null;
                                    await _loadFolders();
                                  }
                                },
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent),
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
                  padding:
                      EdgeInsets.symmetric(horizontal: left + 2, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari catatan...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // LIST

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutQuad,
                    switchOutCurve: Curves.easeInQuad,
                    child: filteredNotes.isEmpty
                        ? const _EmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadNotes,
                            displacement: 24,
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics()),
                              padding: EdgeInsets.fromLTRB(
                                  left + 6, 8, left + 6, 120),
                              itemCount: filteredNotes.length,
                              itemBuilder: (context, i) {
                                final note = filteredNotes[i];
                                final isPinned =
                                    pinnedNoteIds.contains(note.id);
                                return Dismissible(
                                  key: ValueKey(note.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF143D59),
                                          Color(0xFF1B5F8C)
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(Icons.delete,
                                        color: Colors.white, size: 26),
                                  ),
                                  confirmDismiss: (direction) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Hapus Catatan'),
                                        content: const Text(
                                            'Yakin ingin menghapus catatan ini?'),
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
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    return confirm == true;
                                  },
                                  onDismissed: (direction) async {
                                    await DatabaseHelper.instance
                                        .deleteNote(note.id!);
                                    await _loadNotes();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Catatan dihapus')),
                                      );
                                    }
                                  },
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 350),
                                      curve: Curves.easeInOut,
                                      decoration: BoxDecoration(
                                        gradient: isPinned
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFFFD180),
                                                  Color(0xFFFFF1CD)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : const LinearGradient(
                                                colors: [
                                                  Color(0xFFFFFFFF),
                                                  Color(0xFFFFF5E4)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.08),
                                            blurRadius: 14,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 16),
                                        leading: Container(
                                          width: 46,
                                          height: 46,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF0F4C75),
                                                Color(0xFF143D59)
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.notes,
                                              color: Colors.white),
                                        ),
                                        title: Text(
                                          note.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: clamp(w * 0.042, 16, 20),
                                            color: const Color(0xFF143D59),
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            note.content,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF6B6B6B),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                        trailing: IconButton(
                                          icon: Icon(
                                            isPinned
                                                ? Icons.push_pin
                                                : Icons.push_pin_outlined,
                                            color: const Color(0xFFF4B41A),
                                          ),
                                          tooltip: isPinned
                                              ? 'Lepas Pin'
                                              : 'Sematkan',
                                          onPressed: () => _togglePin(note),
                                        ),
                                        onTap: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ViewNotePage(
                                                      note: note,
                                                      isEditing: true),
                                            ),
                                          );
                                          if (result == true) {
                                            await _loadNotes();
                                          }
                                        },
                                        onLongPress: () {
                                          final text =
                                              '${note.title}\n\n${note.content}';
                                          Share.share(text);
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
              ],
            ),

            // FAB
            Positioned(
              bottom: 24,
              right: 24,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFFF4B41A).withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  onPressed: _addNote,
                  backgroundColor: const Color(0xFFF4B41A),
                  foregroundColor: const Color(0xFF143D59),
                  elevation: 0,
                  tooltip: 'Catatan Baru',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.edit_note, size: 30),
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
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.auto_awesome, size: 72, color: Color(0xFF0F4C75)),
          SizedBox(height: 16),
          Text(
            'Belum ada catatan',
            style: TextStyle(
              color: Color(0xFF143D59),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Mulai tulis ide terbaikmu sekarang',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B6B6B),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudConfig {
  const _CloudConfig({
    required this.speed,
    required this.topFactor,
    required this.size,
    required this.opacity,
    required this.phase,
  });

  final double speed;
  final double topFactor;
  final double size;
  final double opacity;
  final double phase;
}

class _AppBarWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 20);
    final firstControlPoint = Offset(size.width * 0.25, size.height);
    final firstEndPoint = Offset(size.width * 0.5, size.height - 16);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );
    final secondControlPoint = Offset(size.width * 0.75, size.height - 36);
    final secondEndPoint = Offset(size.width, size.height - 12);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
