import 'package:share_plus/share_plus.dart';

void shareNoteToWhatsApp(String note) {
  // Membagikan catatan ke WhatsApp (atau aplikasi lain)
  Share.share(note);
}

void shareAllKas(List<Map<String, dynamic>> kasList) {
  if (kasList.isEmpty) {
    Share.share('Tidak ada data kas untuk dibagikan.');
    return;
  }
  final buffer = StringBuffer();
  buffer.writeln('📒 Data Kas:');
  buffer.writeln('==============================');
  for (final kas in kasList) {
    final tgl = kas['tanggal'] ?? '';
    final ket = kas['keterangan'] ?? '';
    final tipe = (kas['isMasuk'] == 1 || kas['isMasuk'] == true) ? 'Masuk' : 'Keluar';
    final jumlah = kas['jumlah'] ?? 0;
    buffer.writeln('Tanggal: $tgl');
    buffer.writeln('Keterangan: $ket');
    buffer.writeln('Tipe: $tipe');
    buffer.writeln('Jumlah: Rp $jumlah');
    buffer.writeln('------------------------------');
  }
  // Total saldo
  final total = kasList.fold<int>(0, (sum, kas) => sum + (((kas['isMasuk'] == 1 || kas['isMasuk'] == true) ? (kas['jumlah'] ?? 0) : -(kas['jumlah'] ?? 0)) as int));
  buffer.writeln('TOTAL SALDO: Rp $total');
  buffer.writeln('==============================');
  Share.share(buffer.toString());
}
