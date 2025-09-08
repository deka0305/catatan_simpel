import 'package:flutter/material.dart';
import 'dart:ui';
import 'db_helper.dart';
import 'package:intl/intl.dart';

class UsahaPage extends StatefulWidget {
  const UsahaPage({Key? key}) : super(key: key);

  @override
  State<UsahaPage> createState() => _UsahaPageState();
}

class _UsahaPageState extends State<UsahaPage> {
  List<Map<String, dynamic>> usahaFolders = [];
  final NumberFormat _idrFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final data = await DatabaseHelper.instance.getUsahaFolders();
    setState(() {
      usahaFolders = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usaha'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF143D59), Color(0xFF1E4E73)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF5E4), Color(0xFFFFF1D4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: usahaFolders.isEmpty
            ? const Center(
                child: Text('Belum ada folder.',
                    style: TextStyle(color: Color(0xFFB0A295), fontSize: 18)))
            : RefreshIndicator(
                onRefresh: _loadFolders,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: usahaFolders.length,
                  itemBuilder: (context, index) {
                    final folder = usahaFolders[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        leading: Hero(
                          tag: 'folderIcon_${folder['id']}',
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFFF4B41A),
                            child: const Icon(Icons.folder,
                                color: Color(0xFF143D59)),
                          ),
                        ),
                        title: Hero(
                          tag: 'folderTitle_${folder['id']}',
                          flightShuttleBuilder:
                              (context, animation, direction, from, to) =>
                                  FadeTransition(
                                      opacity: animation, child: to.widget),
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              folder['nama'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        subtitle: FutureBuilder<List<Map<String, dynamic>>>(
                          future: DatabaseHelper.instance
                              .getUsahaKasList(folder['id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Text('Memuat...');
                            }
                            final kas = snapshot.data ?? [];
                            int pemasukan = kas
                                .where((k) => k['tipe'] == 'Pemasukan')
                                .fold(0,
                                    (a, b) => a + ((b['nominal'] ?? 0) as int));
                            int pengeluaran = kas
                                .where((k) => k['tipe'] == 'Pengeluaran')
                                .fold(0,
                                    (a, b) => a + ((b['nominal'] ?? 0) as int));
                            int saldo = pemasukan - pengeluaran;
                            final total = (pemasukan + pengeluaran).toDouble();
                            final ratio = total == 0
                                ? 0.5
                                : (pemasukan / total).clamp(0.0, 1.0);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip(
                                      avatar: const Icon(Icons.arrow_downward,
                                          size: 18, color: Colors.white),
                                      label: Text(_idrFormat.format(pemasukan)),
                                      labelStyle: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                      backgroundColor: const Color(0xFF4CAF50),
                                    ),
                                    Chip(
                                      avatar: const Icon(Icons.arrow_upward,
                                          size: 18, color: Colors.white),
                                      label:
                                          Text(_idrFormat.format(pengeluaran)),
                                      labelStyle: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                      backgroundColor: const Color(0xFFF44336),
                                    ),
                                    Chip(
                                      avatar: const Icon(Icons.receipt_long,
                                          size: 18, color: Color(0xFF143D59)),
                                      label: Text('Kas: ${kas.length}'),
                                      backgroundColor: const Color(0xFFEDE7DC),
                                      labelStyle: const TextStyle(
                                          color: Color(0xFF143D59)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final barWidth = constraints.maxWidth;
                                    return Stack(
                                      children: [
                                        Container(
                                          width: barWidth,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.grey.withOpacity(0.25),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 350),
                                          curve: Curves.easeOutCubic,
                                          width: barWidth * ratio,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4CAF50),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Saldo: ' + _idrFormat.format(saldo),
                                  style: TextStyle(
                                    color: saldo >= 0
                                        ? Colors.green[800]
                                        : Colors.red[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UsahaKasDetailPage(
                                  folderId: folder['id'],
                                  folderName: folder['nama']),
                            ),
                          );
                          _loadFolders();
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Hapus Folder',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                backgroundColor: const Color(0xFFFFF5E4),
                                title: const Text('Hapus Folder',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                content: Text(
                                    'Yakin ingin menghapus folder "${folder['nama']}"? Semua data kas di dalamnya juga akan dihapus.'),
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
                                  .deleteUsahaFolder(folder['id']);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Folder dihapus')),
                                );
                              }
                              _loadFolders();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final folderName = await showDialog<String>(
            context: context,
            builder: (context) {
              String tempName = '';
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                backgroundColor: const Color(0xFFFFF5E4),
                title: const Text('Tambah Folder',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                content: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Nama folder',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (value) => tempName = value,
                ),
                actionsPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, tempName),
                    child: const Text('Simpan'),
                  ),
                ],
              );
            },
          );
          if (folderName != null && folderName.trim().isNotEmpty) {
            await DatabaseHelper.instance.insertUsahaFolder(folderName.trim());
            _loadFolders();
          }
        },
        label: const Text('Folder Baru'),
        icon: const Icon(Icons.create_new_folder),
        backgroundColor: const Color(0xFFF4B41A),
        foregroundColor: const Color(0xFF143D59),
        tooltip: 'Tambah Folder',
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String value;
  final double? width;

  const _SummaryCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.value,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bgGradient = LinearGradient(
      colors: [
        color.withOpacity(0.12),
        color.withOpacity(0.06),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.30)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Text(
                    value,
                    key: ValueKey(value),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UsahaKasDetailPage extends StatefulWidget {
  final int folderId;
  final String folderName;
  const UsahaKasDetailPage(
      {Key? key, required this.folderId, required this.folderName})
      : super(key: key);

  @override
  State<UsahaKasDetailPage> createState() => _UsahaKasDetailPageState();
}

class _UsahaKasDetailPageState extends State<UsahaKasDetailPage> {
  List<Map<String, dynamic>> kasList = [];
  final NumberFormat _idrFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadKas();
  }

  Future<void> _loadKas() async {
    final data = await DatabaseHelper.instance.getUsahaKasList(widget.folderId);
    setState(() {
      kasList = data;
    });
  }

  void _showMultiInputUsahaKas() async {
    final _formKey = GlobalKey<FormState>();
    List<TextEditingController> keteranganControllers = [
      TextEditingController()
    ];
    List<TextEditingController> jumlahControllers = [TextEditingController()];
    List<bool> isMasukList = [true];
    DateTime tanggal = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E4),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: StatefulBuilder(
              builder: (context, setStateDialog) => Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.playlist_add,
                              color: Color(0xFFF4B41A), size: 28),
                          const SizedBox(width: 10),
                          const Text('Input Kas',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF143D59))),
                          const Spacer(),
                          CircleAvatar(
                            backgroundColor: Colors.red[50],
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.date_range,
                              color: Color(0xFF143D59)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${tanggal.day.toString().padLeft(2, '0')}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.year}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_calendar,
                                color: Color(0xFFF4B41A)),
                            label: const Text('Pilih Tanggal'),
                            style: TextButton.styleFrom(
                                foregroundColor: Color(0xFF143D59),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tanggal,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF143D59),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFFFFF5E4),
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setStateDialog(() => tanggal = picked);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 420;
                          final itemWidth = isWide
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Wrap(
                              key: ValueKey(keteranganControllers.length),
                              spacing: 12,
                              runSpacing: 12,
                              children: List.generate(
                                  keteranganControllers.length, (i) {
                                final masuk = isMasukList[i];
                                return SizedBox(
                                  width: itemWidth,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: masuk
                                          ? const Color(0xFFE8F5E9)
                                          : const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: masuk
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFFF44336),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: masuk
                                                    ? const Color(0xFF4CAF50)
                                                    : const Color(0xFFF44336),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      masuk
                                                          ? Icons.arrow_downward
                                                          : Icons.arrow_upward,
                                                      size: 14,
                                                      color: Colors.white),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                      masuk
                                                          ? 'Pemasukan'
                                                          : 'Pengeluaran',
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              tooltip: 'Hapus Baris',
                                              icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.red),
                                              onPressed: keteranganControllers
                                                          .length >
                                                      1
                                                  ? () {
                                                      setStateDialog(() {
                                                        keteranganControllers
                                                            .removeAt(i);
                                                        jumlahControllers
                                                            .removeAt(i);
                                                        isMasukList.removeAt(i);
                                                      });
                                                    }
                                                  : null,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: keteranganControllers[i],
                                          decoration: InputDecoration(
                                            labelText: 'Keterangan',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 10),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Wajib diisi'
                                                  : null,
                                          maxLines: 1,
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: jumlahControllers[i],
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Jumlah',
                                            prefixText: 'Rp ',
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                    horizontal: 10),
                                          ),
                                          style: const TextStyle(fontSize: 14),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Wajib diisi'
                                                  : null,
                                          maxLines: 1,
                                          onChanged: (value) {
                                            String digits = value.replaceAll(
                                                RegExp(r'[^0-9]'), '');
                                            if (digits.isEmpty) {
                                              jumlahControllers[i].text = '';
                                              jumlahControllers[i].selection =
                                                  const TextSelection.collapsed(
                                                      offset: 0);
                                              return;
                                            }
                                            final number = int.parse(digits);
                                            final formatted =
                                                NumberFormat.currency(
                                                        locale: 'id_ID',
                                                        symbol: '',
                                                        decimalDigits: 0)
                                                    .format(number)
                                                    .trim();
                                            jumlahControllers[i].text =
                                                formatted;
                                            jumlahControllers[i].selection =
                                                TextSelection.collapsed(
                                                    offset: formatted.length);
                                            setStateDialog(() {});
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: ToggleButtons(
                                            isSelected: [masuk, !masuk],
                                            onPressed: (idx) {
                                              setStateDialog(() =>
                                                  isMasukList[i] = idx == 0);
                                            },
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            selectedColor: Colors.white,
                                            fillColor: masuk
                                                ? const Color(0xFF4CAF50)
                                                : const Color(0xFFF44336),
                                            children: const [
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8),
                                                child: Row(children: [
                                                  Icon(Icons.arrow_downward,
                                                      size: 16),
                                                  SizedBox(width: 4),
                                                  Text('Masuk')
                                                ]),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8),
                                                child: Row(children: [
                                                  Icon(Icons.arrow_upward,
                                                      size: 16),
                                                  SizedBox(width: 4),
                                                  Text('Keluar')
                                                ]),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add_circle,
                              color: Color(0xFF4CAF50)),
                          label: const Text('Tambah Baris'),
                          style: TextButton.styleFrom(
                              foregroundColor: Color(0xFF143D59)),
                          onPressed: () {
                            setStateDialog(() {
                              keteranganControllers
                                  .add(TextEditingController());
                              jumlahControllers.add(TextEditingController());
                              isMasukList.add(true);
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon:
                              const Icon(Icons.save, color: Color(0xFF143D59)),
                          label: const Text('Simpan Semua'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFF4B41A),
                            foregroundColor: Color(0xFF143D59),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              for (int i = 0;
                                  i < keteranganControllers.length;
                                  i++) {
                                String digits = jumlahControllers[i]
                                    .text
                                    .replaceAll(RegExp(r'[^0-9]'), '');
                                await DatabaseHelper.instance.insertUsahaKas(
                                  folderId: widget.folderId,
                                  tanggal:
                                      '${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}',
                                  keterangan: keteranganControllers[i].text,
                                  nominal: int.tryParse(digits) ?? 0,
                                  tipe: isMasukList[i]
                                      ? 'Pemasukan'
                                      : 'Pengeluaran',
                                );
                              }
                              Navigator.pop(context);
                              await _loadKas();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'folderTitle_${widget.folderId}',
          flightShuttleBuilder: (context, animation, direction, from, to) =>
              FadeTransition(opacity: animation, child: to.widget),
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              widget.folderName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white, // warna putih
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF143D59), Color(0xFF1E4E73)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF5E4), Color(0xFFFFF1D4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: kasList.isEmpty
            ? const Center(
                child: Text('Belum ada data kas.',
                    style: TextStyle(color: Color(0xFFB0A295), fontSize: 18)))
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: kasList.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Summary header
                    final pemasukan = kasList
                        .where((k) => k['tipe'] == 'Pemasukan')
                        .fold<int>(
                            0, (a, b) => a + ((b['nominal'] ?? 0) as int));
                    final pengeluaran = kasList
                        .where((k) => k['tipe'] == 'Pengeluaran')
                        .fold<int>(
                            0, (a, b) => a + ((b['nominal'] ?? 0) as int));
                    final saldo = pemasukan - pengeluaran;
                    final total = (pemasukan + pengeluaran).toDouble();
                    final ratio =
                        total == 0 ? 0.5 : (pemasukan / total).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final maxW = constraints.maxWidth;
                              final columns =
                                  maxW < 380 ? 1 : (maxW < 700 ? 2 : 3);
                              const spacing = 8.0;
                              final itemWidth =
                                  (maxW - spacing * (columns - 1)) / columns;
                              return Wrap(
                                spacing: spacing,
                                runSpacing: spacing,
                                children: [
                                  _SummaryCard(
                                    width: itemWidth,
                                    color: const Color(0xFF4CAF50),
                                    icon: Icons.arrow_downward,
                                    title: 'Pemasukan',
                                    value: _idrFormat.format(pemasukan),
                                  ),
                                  _SummaryCard(
                                    width: itemWidth,
                                    color: const Color(0xFFF44336),
                                    icon: Icons.arrow_upward,
                                    title: 'Pengeluaran',
                                    value: _idrFormat.format(pengeluaran),
                                  ),
                                  _SummaryCard(
                                    width: itemWidth,
                                    color: saldo >= 0
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFC62828),
                                    icon: Icons.account_balance_wallet,
                                    title: 'Saldo',
                                    value: _idrFormat.format(saldo),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) => Stack(
                              children: [
                                Container(
                                  width: constraints.maxWidth,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                  width: constraints.maxWidth * ratio,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  }
                  final kas = kasList[index - 1];
                  final isMasuk = kas['tipe'] == 'Pemasukan';
                  return TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 250),
                    tween: Tween(begin: 0.95, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      color: isMasuk
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isMasuk
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                          child: Icon(
                              isMasuk
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: Colors.white),
                        ),
                        title: Text(
                          kas['keterangan'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${kas['tanggal']} | ${kas['tipe']}',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _idrFormat.format(kas['nominal']),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMasuk
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontSize: 15,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Color(0xFFF4B41A)),
                              tooltip: 'Edit',
                              onPressed: () => _showEditKasDialog(kas),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Hapus',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    backgroundColor: const Color(0xFFFFF5E4),
                                    title: const Text('Hapus Data Kas',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    content: const Text(
                                        'Yakin ingin menghapus data kas ini?'),
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
                                      .deleteUsahaKas(kas['id']);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Data kas dihapus')),
                                    );
                                  }
                                  _loadKas();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inputBanyak',
        onPressed: _showMultiInputUsahaKas,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.playlist_add),
        label: const Text('Input Banyak'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Input Kas Banyak',
      ),
    );
  }

  void _showEditKasDialog(Map<String, dynamic> kas) async {
    final _formKey = GlobalKey<FormState>();
    final keteranganController =
        TextEditingController(text: kas['keterangan'] ?? '');
    final jumlahController =
        TextEditingController(text: kas['nominal']?.toString() ?? '');
    bool isMasuk = kas['tipe'] == 'Pemasukan';
    DateTime tanggal =
        DateTime.tryParse(kas['tanggal'] ?? '') ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: LayoutBuilder(
          builder: (context, constraints) => ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF5E4), Color(0xFFFFF1D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                child: StatefulBuilder(
                  builder: (context, setStateDialog) => Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.edit,
                                  color: Color(0xFFF4B41A), size: 28),
                              const SizedBox(width: 10),
                              const Text('Edit Kas',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF143D59))),
                              const Spacer(),
                              CircleAvatar(
                                backgroundColor: Colors.red[50],
                                child: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.date_range,
                                  color: Color(0xFF143D59)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${tanggal.day.toString().padLeft(2, '0')}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.year}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit_calendar,
                                    color: Color(0xFFF4B41A)),
                                label: const Text('Pilih Tanggal'),
                                style: TextButton.styleFrom(
                                    foregroundColor: Color(0xFF143D59),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tanggal,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    builder: (context, child) => Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFF143D59),
                                          onPrimary: Colors.white,
                                          surface: Color(0xFFFFF5E4),
                                        ),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) {
                                    setStateDialog(() => tanggal = picked);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: keteranganController,
                                  decoration: InputDecoration(
                                    labelText: 'Keterangan',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 10),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: jumlahController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Jumlah',
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 10),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<bool>(
                                        value: true,
                                        groupValue: isMasuk,
                                        activeColor: Color(0xFF4CAF50),
                                        onChanged: (v) => setStateDialog(
                                            () => isMasuk = true),
                                      ),
                                      const Text('Masuk',
                                          style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Radio<bool>(
                                        value: false,
                                        groupValue: isMasuk,
                                        activeColor: Color(0xFFF44336),
                                        onChanged: (v) => setStateDialog(
                                            () => isMasuk = false),
                                      ),
                                      const Text('Keluar',
                                          style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save,
                                  color: Color(0xFF143D59)),
                              label: const Text('Simpan Perubahan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFF4B41A),
                                foregroundColor: Color(0xFF143D59),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  await DatabaseHelper.instance.insertUsahaKas(
                                    folderId: widget.folderId,
                                    tanggal:
                                        '${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}',
                                    keterangan: keteranganController.text,
                                    nominal:
                                        int.tryParse(jumlahController.text) ??
                                            0,
                                    tipe: isMasuk ? 'Pemasukan' : 'Pengeluaran',
                                  );
                                  await DatabaseHelper.instance
                                      .deleteUsahaKas(kas['id']);
                                  Navigator.pop(context);
                                  await _loadKas();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
