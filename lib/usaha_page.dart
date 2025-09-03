import 'package:flutter/material.dart';
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
      ),
      body: usahaFolders.isEmpty
          ? const Center(
              child: Text('Belum ada folder.',
                  style: TextStyle(color: Color(0xFFB0A295), fontSize: 18)))
          : ListView.builder(
              itemCount: usahaFolders.length,
              itemBuilder: (context, index) {
                final folder = usahaFolders[index];
                return Card(
                  elevation: 3,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF4B41A),
                      child: const Icon(Icons.folder, color: Color(0xFF143D59)),
                    ),
                    title: Text(folder['nama'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: FutureBuilder<List<Map<String, dynamic>>>(
                      future:
                          DatabaseHelper.instance.getUsahaKasList(folder['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text('Memuat...');
                        }
                        final kas = snapshot.data ?? [];
                        int pemasukan = kas
                            .where((k) => k['tipe'] == 'Pemasukan')
                            .fold(
                                0, (a, b) => a + ((b['nominal'] ?? 0) as int));
                        int pengeluaran = kas
                            .where((k) => k['tipe'] == 'Pengeluaran')
                            .fold(
                                0, (a, b) => a + ((b['nominal'] ?? 0) as int));
                        int saldo = pemasukan - pengeluaran;
                        return Row(
                          children: [
                            Text(
                              'Saldo: ',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _idrFormat.format(saldo),
                              style: TextStyle(
                                color: saldo >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Kas: ${kas.length}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                overflow: TextOverflow
                                    .ellipsis, // biar tidak overflow
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
                            title: const Text('Hapus Folder'),
                            content: Text('Yakin ingin menghapus folder "${folder['nama']}"? Semua data kas di dalamnya juga akan dihapus.'),
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
                          await DatabaseHelper.instance.deleteUsahaFolder(folder['id']);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Folder dihapus')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final folderName = await showDialog<String>(
            context: context,
            builder: (context) {
              String tempName = '';
              return AlertDialog(
                title: const Text('Tambah Folder'),
                content: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Nama folder'),
                  onChanged: (value) => tempName = value,
                ),
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
        child: const Icon(Icons.create_new_folder),
        tooltip: 'Tambah Folder',
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
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: keteranganControllers.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: TextFormField(
                                  controller: keteranganControllers[i],
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
                                child: StatefulBuilder(
                                  builder: (context, setStateField) {
                                    return TextFormField(
                                      controller: jumlahControllers[i],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Jumlah',
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 10),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                      validator: (v) => v == null || v.isEmpty
                                          ? 'Wajib diisi'
                                          : null,
                                      maxLines: 1,
                                      inputFormatters: [],
                                      onChanged: (value) {
                                        String digits = value.replaceAll(
                                            RegExp(r'[^0-9]'), '');
                                        if (digits.isEmpty) {
                                          jumlahControllers[i].text = '';
                                          jumlahControllers[i].selection =
                                              TextSelection.collapsed(
                                                  offset: 0);
                                          return;
                                        }
                                        final number = int.parse(digits);
                                        final formatted = NumberFormat.currency(
                                                locale: 'id_ID',
                                                symbol: '',
                                                decimalDigits: 0)
                                            .format(number)
                                            .trim();
                                        jumlahControllers[i].text = formatted;
                                        jumlahControllers[i].selection =
                                            TextSelection.collapsed(
                                                offset: formatted.length);
                                        setStateField(() {});
                                      },
                                    );
                                  },
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
                                        groupValue: isMasukList[i],
                                        activeColor: Color(0xFF4CAF50),
                                        onChanged: (v) => setStateDialog(
                                            () => isMasukList[i] = true),
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
                                        groupValue: isMasukList[i],
                                        activeColor: Color(0xFFF44336),
                                        onChanged: (v) => setStateDialog(
                                            () => isMasukList[i] = false),
                                      ),
                                      const Text('Keluar',
                                          style: TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                                tooltip: 'Hapus Baris',
                                onPressed: keteranganControllers.length > 1
                                    ? () {
                                        setStateDialog(() {
                                          keteranganControllers.removeAt(i);
                                          jumlahControllers.removeAt(i);
                                          isMasukList.removeAt(i);
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
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
        title: Text(widget.folderName),
      ),
      body: kasList.isEmpty
          ? const Center(
              child: Text('Belum ada data kas.',
                  style: TextStyle(color: Color(0xFFB0A295), fontSize: 18)))
          : ListView.builder(
              itemCount: kasList.length,
              itemBuilder: (context, index) {
                final kas = kasList[index];
                final isMasuk = kas['tipe'] == 'Pemasukan';
                return Card(
                  elevation: 2,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  color: isMasuk
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isMasuk
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF44336),
                      child: Icon(
                          isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
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
                        Text(_idrFormat.format(kas['nominal']),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMasuk
                                    ? Colors.green[800]
                                    : Colors.red[800],
                                fontSize: 15)),
                        IconButton(
                          icon:
                              const Icon(Icons.edit, color: Color(0xFFF4B41A)),
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
                                title: const Text('Hapus Data Kas'),
                                content: const Text('Yakin ingin menghapus data kas ini?'),
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
                              await DatabaseHelper.instance.deleteUsahaKas(kas['id']);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Data kas dihapus')),
                                );
                              }
                              _loadKas();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'inputBanyak',
        onPressed: _showMultiInputUsahaKas,
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        child: const Icon(Icons.playlist_add, size: 28),
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
                                    borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 10),
                              ),
                              style: const TextStyle(fontSize: 14),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Wajib diisi' : null,
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
                                    borderRadius: BorderRadius.circular(10)),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 10),
                              ),
                              style: const TextStyle(fontSize: 14),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Wajib diisi' : null,
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
                                    onChanged: (v) =>
                                        setStateDialog(() => isMasuk = true),
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
                                    onChanged: (v) =>
                                        setStateDialog(() => isMasuk = false),
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
                          icon:
                              const Icon(Icons.save, color: Color(0xFF143D59)),
                          label: const Text('Simpan Perubahan'),
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
                              await DatabaseHelper.instance.insertUsahaKas(
                                folderId: widget.folderId,
                                tanggal:
                                    '${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}',
                                keterangan: keteranganController.text,
                                nominal:
                                    int.tryParse(jumlahController.text) ?? 0,
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
    );
  }
}
