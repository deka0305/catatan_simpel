import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'models.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Tambahkan ini
import 'package:share_plus/share_plus.dart';

class KasPage extends StatefulWidget {
  const KasPage({super.key});

  @override
  State<KasPage> createState() => _KasPageState();
}

class _KasPageState extends State<KasPage> {
  List<Kas> kasList = [];
  DateTime today = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null); // Inisialisasi locale Indonesia
    _loadKas();
  }

  Future<void> _loadKas() async {
    kasList = await DatabaseHelper.instance.getKasList();
    setState(() {});
  }

  void _showInputKas({Kas? kas}) async {
    final _formKey = GlobalKey<FormState>();
    final keteranganController =
        TextEditingController(text: kas?.keterangan ?? '');
    final jumlahController = TextEditingController(
        text: kas?.jumlah != null ? kas!.jumlah.toString() : '');
    bool isMasuk = kas?.isMasuk ?? true;
    DateTime tanggal = kas?.tanggal ?? DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: StatefulBuilder(
            builder: (context, setStateDialog) => Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          kas == null
                              ? Icons.add_circle_outline
                              : Icons.edit_note,
                          color: Color(0xFFF4B41A),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          kas == null ? 'Input Kas' : 'Edit Kas',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF143D59),
                          ),
                        ),
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
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: keteranganController,
                      decoration: InputDecoration(
                        labelText: 'Keterangan',
                        prefixIcon: const Icon(Icons.description,
                            color: Color(0xFF143D59)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: jumlahController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Jumlah',
                        prefixIcon: const Icon(Icons.attach_money,
                            color: Color(0xFFF4B41A)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            value: true,
                            groupValue: isMasuk,
                            title: const Text('Masuk',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            activeColor: Color(0xFF4CAF50),
                            tileColor: isMasuk
                                ? Color(0xFFB0E57C).withOpacity(0.3)
                                : null,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            onChanged: (v) =>
                                setStateDialog(() => isMasuk = true),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            value: false,
                            groupValue: isMasuk,
                            title: const Text('Keluar',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            activeColor: Color(0xFFF44336),
                            tileColor: !isMasuk
                                ? Color(0xFFFFC1C1).withOpacity(0.3)
                                : null,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            onChanged: (v) =>
                                setStateDialog(() => isMasuk = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.date_range, color: Color(0xFF143D59)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, dd MMM yyyy', 'id_ID')
                                .format(tanggal),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.edit_calendar,
                              color: Color(0xFFF4B41A)),
                          label: const Text('Pilih Tanggal'),
                          style: TextButton.styleFrom(
                            foregroundColor: Color(0xFF143D59),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(kas == null ? Icons.save : Icons.edit,
                            color: Color(0xFF143D59)),
                        label: Text(kas == null ? 'Simpan' : 'Update'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF4B41A),
                          foregroundColor: Color(0xFF143D59),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.bold),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            if (kas == null) {
                              final kasBaru = Kas(
                                keterangan: keteranganController.text,
                                jumlah:
                                    int.tryParse(jumlahController.text) ?? 0,
                                isMasuk: isMasuk,
                                tanggal: tanggal,
                              );
                              await DatabaseHelper.instance.insertKas(kasBaru);
                            } else {
                              final kasUpdate = Kas(
                                id: kas.id,
                                keterangan: keteranganController.text,
                                jumlah:
                                    int.tryParse(jumlahController.text) ?? 0,
                                isMasuk: isMasuk,
                                tanggal: tanggal,
                              );
                              await DatabaseHelper.instance
                                  .updateKas(kasUpdate);
                            }
                            Navigator.pop(context);
                            await _loadKas();
                            setState(() {
                              today = DateTime.now();
                            });
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
    );
  }

  void _deleteKas(int id) async {
    await DatabaseHelper.instance.deleteKas(id);
    _loadKas();
  }

  int get totalKas {
    int total = 0;
    for (final kas in kasList) {
      total += kas.isMasuk ? kas.jumlah : -kas.jumlah;
    }
    return total;
  }

  List<Kas> get todayKasList {
    return kasList
        .where((k) =>
            k.tanggal.year == today.year &&
            k.tanggal.month == today.month &&
            k.tanggal.day == today.day)
        .toList();
  }

  int get todayKasTotal {
    return todayKasList.fold(
        0, (sum, k) => sum + (k.isMasuk ? k.jumlah : -k.jumlah));
  }

  void _goToLaporanHarian() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LaporanHarianPage()),
    );
  }

  void _goToLaporanBulanan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LaporanBulananPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E4),
      appBar: AppBar(
        title: const Text('Kas'),
        backgroundColor: const Color(0xFF143D59),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Color(0xFFF4B41A)),
            tooltip: 'Laporan Harian',
            onPressed: _goToLaporanHarian,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color(0xFFF4B41A)),
            tooltip: 'Laporan Bulanan',
            onPressed: _goToLaporanBulanan,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInputKas(),
        backgroundColor: const Color(0xFFF4B41A),
        foregroundColor: const Color(0xFF143D59),
        child: const Icon(Icons.add, size: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Input Kas',
      ),
      body: Column(
        children: [
          // List kas hari ini di bawah appbar
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF143D59),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.chevron_left, color: Colors.white70),
                      tooltip: 'Hari sebelumnya',
                      onPressed: () {
                        setState(() {
                          today = today.subtract(const Duration(days: 1));
                        });
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Kas Hari Ini (${DateFormat('dd MMM yyyy').format(today)})',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 15),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right,
                          color: Colors.white70),
                      tooltip: 'Hari berikutnya',
                      onPressed: () {
                        setState(() {
                          today = today.add(const Duration(days: 1));
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp ${NumberFormat('#,##0', 'id_ID').format(todayKasTotal)}',
                  style: const TextStyle(
                    color: Color(0xFFF4B41A),
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Kas Hari Ini',
                        style: TextStyle(
                          color: Color(0xFFB0A295),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Balance: Rp ${NumberFormat('#,##0', 'id_ID').format(totalKas)}',
                  style: const TextStyle(
                    color: Color(0xFFB0A295),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: todayKasList.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data kas hari ini',
                      style: TextStyle(color: Color(0xFFB0A295), fontSize: 18),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: todayKasList.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final kas = todayKasList[i];
                      return Card(
                        color: kas.isMasuk
                            ? const Color(0xFFB0E57C)
                            : const Color(0xFFFFC1C1),
                        elevation: 3,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          leading: CircleAvatar(
                            backgroundColor: kas.isMasuk
                                ? const Color(0xFFF4B41A)
                                : const Color(0xFF143D59),
                            child: Icon(
                              kas.isMasuk
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            kas.keterangan,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF143D59),
                            ),
                          ),
                          subtitle: Text(
                            'Rp ${kas.jumlah} - ${kas.isMasuk ? "Masuk" : "Keluar"}',
                            style: const TextStyle(color: Color(0xFFB0A295)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Color(0xFFF4B41A)),
                            onPressed: () => _deleteKas(kas.id!),
                            tooltip: 'Hapus',
                          ),
                          onTap: () => _showInputKas(kas: kas),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Halaman laporan harian
class LaporanHarianPage extends StatefulWidget {
  const LaporanHarianPage({super.key});

  @override
  State<LaporanHarianPage> createState() => _LaporanHarianPageState();
}

class _LaporanHarianPageState extends State<LaporanHarianPage> {
  DateTime selectedDate = DateTime.now();

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
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
      setState(() => selectedDate = picked);
    }
  }

  void _slideDay(int delta) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: delta));
    });
  }

  Future<void> _deleteKasWithConfirm(int id) async {
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
      await DatabaseHelper.instance.deleteKas(id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Harian'),
        backgroundColor: const Color(0xFF143D59),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Hari sebelumnya',
            onPressed: () => _slideDay(-1),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Hari berikutnya',
            onPressed: () => _slideDay(1),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Pilih Tanggal',
            onPressed: _pickDate,
          ),
        ],
      ),
      body: FutureBuilder<List<Kas>>(
        future: DatabaseHelper.instance.getKasList(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final kasList = snapshot.data!
              .where((k) =>
                  k.tanggal.year == selectedDate.year &&
                  k.tanggal.month == selectedDate.month &&
                  k.tanggal.day == selectedDate.day)
              .toList();

          final Map<String, List<Kas>> grouped = {};
          for (final kas in kasList) {
            final key = DateFormat('dd/MM/yyyy').format(kas.tanggal);
            grouped.putIfAbsent(key, () => []).add(kas);
          }
          final sortedKeys = grouped.keys.toList()
            ..sort((a, b) => DateFormat('dd/MM/yyyy')
                .parse(b)
                .compareTo(DateFormat('dd/MM/yyyy').parse(a)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedKeys.length,
            itemBuilder: (context, idx) {
              final tgl = sortedKeys[idx];
              final list = grouped[tgl]!;
              final total = list.fold(
                  0, (sum, k) => sum + (k.isMasuk ? k.jumlah : -k.jumlah));
              return Card(
                color: const Color(0xFF143D59),
                margin: const EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Color(0xFFF4B41A), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Tanggal $tgl',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Rp $total',
                            style: const TextStyle(
                              color: Color(0xFFF4B41A),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...list.map((kas) => Dismissible(
                            key: ValueKey(kas.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete,
                                  color: Colors.white, size: 28),
                            ),
                            confirmDismiss: (_) async {
                              await _deleteKasWithConfirm(kas.id!);
                              return false; // prevent auto-dismiss, manual refresh
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: kas.isMasuk
                                    ? const Color(0xFFB0E57C)
                                    : const Color(0xFFFFC1C1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: kas.isMasuk
                                      ? const Color(0xFFF4B41A)
                                      : const Color(0xFF143D59),
                                  child: Icon(
                                    kas.isMasuk
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  kas.keterangan,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: kas.isMasuk
                                        ? Color(0xFF143D59)
                                        : Color(0xFFF44336),
                                  ),
                                ),
                                subtitle: Text(
                                  'Rp ${kas.jumlah} - ${kas.isMasuk ? "Masuk" : "Keluar"}',
                                  style: TextStyle(
                                    color: kas.isMasuk
                                        ? Color(0xFF4CAF50)
                                        : Color(0xFFF44336),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Halaman laporan bulanan
class LaporanBulananPage extends StatefulWidget {
  const LaporanBulananPage({super.key});

  @override
  State<LaporanBulananPage> createState() => _LaporanBulananPageState();
}

class _LaporanBulananPageState extends State<LaporanBulananPage> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
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
      setState(() => selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  void _slideMonth(int delta) {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + delta);
    });
  }

  Future<void> _deleteKasWithConfirm(int id) async {
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
      await DatabaseHelper.instance.deleteKas(id);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Laporan Bulanan'),
            backgroundColor: const Color(0xFF143D59),
            actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Bulan sebelumnya',
              onPressed: () => _slideMonth(-1),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Bulan berikutnya',
              onPressed: () => _slideMonth(1),
            ),
            IconButton(
              icon: const Icon(Icons.date_range),
              tooltip: 'Pilih Bulan',
              onPressed: _pickMonth,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Bagikan',
              onPressed: () async {
              final kasList = await DatabaseHelper.instance.getKasList();
              final bulanKas = kasList
              .where((k) =>
                k.tanggal.year == selectedMonth.year &&
                k.tanggal.month == selectedMonth.month)
              .toList();
              if (bulanKas.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tidak ada data kas bulan ini')),
              );
              return;
              }
              final buffer = StringBuffer();
              buffer.writeln('📅 Laporan Kas Bulan ${DateFormat('MMMM yyyy', 'id_ID').format(selectedMonth)}');
              buffer.writeln('========================================');
              buffer.writeln('|   Tanggal   |   Keterangan   |   Masuk/Keluar   |     Jumlah    |');
              buffer.writeln('----------------------------------------');
              for (final kas in bulanKas) {
              final tgl = DateFormat('dd/MM/yyyy').format(kas.tanggal);
              final ket = kas.keterangan.length > 15
                ? kas.keterangan.substring(0, 15) + '…'
                : kas.keterangan.padRight(15);
              final tipe = kas.isMasuk ? 'Masuk ' : 'Keluar';
              final jumlah = NumberFormat('#,##0', 'id_ID').format(kas.jumlah).padLeft(10);
              buffer.writeln('| $tgl | $ket | ${tipe.padRight(7)} | Rp $jumlah |');
              }
              buffer.writeln('----------------------------------------');
              final total = bulanKas.fold(
              0, (sum, k) => sum + (k.isMasuk ? k.jumlah : -k.jumlah));
              buffer.writeln('Total Saldo: Rp ${NumberFormat('#,##0', 'id_ID').format(total)}');
              buffer.writeln('========================================');
              await Share.share(buffer.toString());
              },
            ),
            ],
          ),
        body: FutureBuilder<List<Kas>>(
          future: DatabaseHelper.instance.getKasList(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final kasList = snapshot.data!
                .where((k) =>
                    k.tanggal.year == selectedMonth.year &&
                    k.tanggal.month == selectedMonth.month)
                .toList();

            // Group by day in the selected month
            final Map<String, List<Kas>> grouped = {};
            for (final kas in kasList) {
              final key = DateFormat('dd/MM/yyyy').format(kas.tanggal);
              grouped.putIfAbsent(key, () => []).add(kas);
            }
            final sortedKeys = grouped.keys.toList()
              ..sort((a, b) => DateFormat('dd/MM/yyyy')
                  .parse(b)
                  .compareTo(DateFormat('dd/MM/yyyy').parse(a)));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedKeys.length,
              itemBuilder: (context, idx) {
                final tgl = sortedKeys[idx];
                final list = grouped[tgl]!;
                final total = list.fold(
                    0, (sum, k) => sum + (k.isMasuk ? k.jumlah : -k.jumlah));
                return Card(
                  color: const Color(0xFF143D59),
                  margin: const EdgeInsets.only(bottom: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: Color(0xFFF4B41A), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Tanggal $tgl',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Rp $total',
                              style: const TextStyle(
                                color: Color(0xFFF4B41A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...list.map((kas) => Dismissible(
                              key: ValueKey(kas.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.delete,
                                    color: Colors.white, size: 28),
                              ),
                              confirmDismiss: (_) async {
                                await _deleteKasWithConfirm(kas.id!);
                                return false;
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: kas.isMasuk
                                      ? const Color(0xFFB0E57C)
                                      : const Color(0xFFFFC1C1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    backgroundColor: kas.isMasuk
                                        ? const Color(0xFFF4B41A)
                                        : const Color(0xFF143D59),
                                    child: Icon(
                                      kas.isMasuk
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    kas.keterangan,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kas.isMasuk
                                          ? Color(0xFF143D59)
                                          : Color(0xFFF44336),
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Rp ${kas.jumlah} - ${kas.isMasuk ? "Masuk" : "Keluar"}',
                                    style: TextStyle(
                                      color: kas.isMasuk
                                          ? Color(0xFF4CAF50)
                                          : Color(0xFFF44336),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ));
  }
}
