import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Push-through sync otomatis ke Firebase Realtime Database.
///
/// Prinsip: SQLite lokal (db_helper.dart) adalah sumber data utama.
/// Setiap panggilan di sini best-effort dan TIDAK PERNAH melempar
/// exception ke pemanggil, supaya kegagalan koneksi/Firebase tidak
/// pernah membuat operasi database lokal gagal atau app crash.
///
/// Sama seperti tombol "Sinkronkan ke Cloud" (sync_all_data_page.dart):
/// request dikirim langsung tanpa autentikasi, sehingga rules Firebase
/// Realtime Database untuk project ini harus mengizinkan akses publik.
class FirebaseSyncService {
  FirebaseSyncService._();
  static final FirebaseSyncService instance = FirebaseSyncService._();

  static const String databaseUrl =
      'https://kas-keluarga-47d2d-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Kirim request ke Firebase dan kembalikan true kalau benar-benar
  /// berhasil (status 2xx). Tidak pernah melempar exception — kegagalan
  /// jaringan/HTTP dilaporkan lewat return value false.
  Future<bool> _send(String method, String path,
      [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('$databaseUrl/$path.json');
      http.Response res;
      switch (method) {
        case 'PUT':
          res = await http.put(uri, body: jsonEncode(body));
          break;
        case 'PATCH':
          res = await http.patch(uri, body: jsonEncode(body));
          break;
        case 'DELETE':
          res = await http.delete(uri);
          break;
        default:
          return false;
      }
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('FirebaseSyncService: gagal sync "$path": $e');
      return false;
    }
  }

  /// Timpa seluruh node [path] dengan [data] (dipakai untuk insert).
  void pushSet(String path, Map<String, dynamic> data) {
    unawaited(_send('PUT', path, data));
  }

  /// Update sebagian field di [path] (dipakai untuk update, agar field
  /// lain yang sudah ada di cloud tidak ikut tertimpa/hilang).
  void pushUpdate(String path, Map<String, dynamic> data) {
    unawaited(_send('PATCH', path, data));
  }

  /// Hapus node [path] dari cloud.
  void pushDelete(String path) {
    unawaited(_send('DELETE', path));
  }

  /// Versi yang menunggu hasil (dipakai oleh outbox queue di db_helper.dart
  /// untuk tahu apakah perlu di-retry nanti atau sudah boleh dihapus dari
  /// antrian).
  Future<bool> trySet(String path, Map<String, dynamic> data) =>
      _send('PUT', path, data);
  Future<bool> tryUpdate(String path, Map<String, dynamic> data) =>
      _send('PATCH', path, data);
  Future<bool> tryDelete(String path) => _send('DELETE', path);

  /// Buka koneksi realtime (Server-Sent Events) ke [path] pada Firebase
  /// Realtime Database. Firebase mengirim event "put"/"patch" setiap kali
  /// ada perubahan data, termasuk snapshot lengkap saat pertama connect.
  ///
  /// Stream ini tidak pernah melempar exception; kegagalan koneksi hanya
  /// menghentikan stream (pemanggil bertanggung jawab reconnect).
  Stream<Map<String, dynamic>> streamPath([String path = '']) async* {
    final client = http.Client();
    try {
      final uri = Uri.parse('$databaseUrl/$path.json');
      final request = http.Request('GET', uri)
        ..headers['Accept'] = 'text/event-stream';
      final response = await client.send(request);

      String? currentEvent;
      final buffer = StringBuffer();

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (currentEvent == 'put' || currentEvent == 'patch') {
            try {
              final payload =
                  jsonDecode(buffer.toString()) as Map<String, dynamic>;
              yield {
                'event': currentEvent,
                'path': (payload['path'] as String?) ?? '/',
                'data': payload['data'],
              };
            } catch (_) {
              // Bukan payload put/patch yang valid (mis. keep-alive), abaikan.
            }
          }
          currentEvent = null;
          buffer.clear();
          continue;
        }
        if (line.startsWith('event: ')) {
          currentEvent = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          buffer.write(line.substring(6));
        }
      }
    } catch (e) {
      debugPrint('FirebaseSyncService: realtime stream error: $e');
    } finally {
      client.close();
    }
  }
}
