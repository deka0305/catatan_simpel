import 'package:flutter/foundation.dart';
import 'db_helper.dart';
import 'firebase_sync_service.dart';

/// Menjaga koneksi realtime (SSE) ke Firebase Realtime Database tetap
/// hidup, dan menerapkan setiap perubahan yang masuk ke SQLite lokal
/// lewat [DatabaseHelper.applyCloudEvent]. Reconnect otomatis kalau
/// koneksi putus (mis. jaringan hilang sebentar).
class RealtimeSyncManager {
  RealtimeSyncManager._();
  static final RealtimeSyncManager instance = RealtimeSyncManager._();

  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    // Jaring pengaman: kalau ada antrian outbox tersisa dari sesi
    // sebelumnya (mis. app ditutup sebelum sempat online lagi), coba
    // kirim begitu app dibuka.
    DatabaseHelper.instance.flushOutbox();
    _connectLoop();
  }

  Future<void> _connectLoop() async {
    while (true) {
      try {
        await for (final evt in FirebaseSyncService.instance.streamPath()) {
          final event = evt['event'] as String;
          final path = evt['path'] as String? ?? '/';
          await DatabaseHelper.instance
              .applyCloudEvent(event, path, evt['data']);
        }
      } catch (e) {
        debugPrint('RealtimeSyncManager: stream terputus: $e');
      }
      await Future.delayed(const Duration(seconds: 3));
    }
  }
}
