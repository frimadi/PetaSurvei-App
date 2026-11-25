import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'gudang.dart';
import 'ruas_model.dart';

/// Daftar ruas SK Jalan yang disimpan di HP (ruas.json) agar bisa dipakai tanpa sinyal.
/// Sumbernya Apps Script (?aksi=ruas) yang membaca berkas GeoJSON di folder "referensi" Drive.
class DaftarRuas extends ChangeNotifier {
  final Gudang gudang;
  DaftarRuas(this.gudang);

  List<Ruas> semua = [];
  Map<String, Ruas> _peta = {};
  String versi = '';
  String diperbarui = ''; // waktu daftar terakhir berubah (ISO)
  String diperiksa = ''; // waktu terakhir dicek ke skrip (ISO)
  bool sibuk = false;
  File? _berkas;

  bool get kosong => semua.isEmpty;
  Ruas? cariId(String id) => _peta[id];

  Future<void> muat() async {
    final d = await getApplicationDocumentsDirectory();
    _berkas = File('${d.path}/ruas.json');
    if (!await _berkas!.exists()) return;
    try {
      final j = jsonDecode(await _berkas!.readAsString()) as Map<String, dynamic>;
      versi = (j['versi'] as String?) ?? '';
      diperbarui = (j['diperbarui'] as String?) ?? '';
      diperiksa = (j['diperiksa'] as String?) ?? '';
      semua = uraiRuas((j['r'] as List?) ?? const []);
      _peta = {for (final r in semua) r.id: r};
    } catch (_) {
      // Berkas rusak: abaikan, akan diunduh ulang.
      semua = [];
      versi = '';
    }
  }

  Future<void> _simpan() async {
    final f = _berkas;
    if (f == null) return;
    await f.writeAsString(jsonEncode({
      'versi': versi,
      'diperbarui': diperbarui,
      'diperiksa': diperiksa,
      'r': [for (final r in semua) [r.id, r.nama, r.jenis, r.kec, r.desa]],
    }));
  }

  /// Dipanggil saat aplikasi dibuka: cek ke skrip bila belum pernah atau sudah > 6 jam.
  Future<void> perbaruiOtomatis() async {
    if (gudang.baca('url').trim().isEmpty) return;
    final t = DateTime.tryParse(diperiksa);
    final segar = t != null && DateTime.now().difference(t).inHours < 6 && !kosong;
    if (segar) return;
    await perbarui();
  }

  /// Mengembalikan pesan hasil untuk ditampilkan ke pengguna.
  Future<String> perbarui({bool paksa = false}) async {
    if (sibuk) return 'Sedang memperbarui…';
    final url = gudang.baca('url').trim();
    if (url.isEmpty) return 'Isi alamat skrip di Pengaturan dulu.';
    sibuk = true;
    notifyListeners();
    try {
      final dasar = Uri.parse(url);
      final u = dasar.replace(queryParameters: {
        ...dasar.queryParameters,
        'aksi': 'ruas',
        if (!paksa && versi.isNotEmpty) 'versi': versi,
      });
      final r = await http.get(u).timeout(const Duration(seconds: 90));
      final j = jsonDecode(r.body);
      if (j is! Map) return 'Jawaban skrip tidak dikenali.';
      if (j['ok'] != true) return (j['pesan'] ?? 'Ditolak oleh skrip').toString();
      final sekarang = DateTime.now().toIso8601String();
      if (j['sama'] == true) {
        diperiksa = sekarang;
        await _simpan();
        return 'Daftar ruas sudah yang terbaru (${semua.length} ruas).';
      }
      if (j['r'] is! List) {
        return 'Skrip belum diperbarui ke versi baru (perlu deploy Versi baru).';
      }
      final baru = uraiRuas(j['r'] as List);
      if (baru.isEmpty) return 'Daftar ruas dari skrip kosong. Periksa berkas di folder referensi.';
      semua = baru;
      _peta = {for (final x in baru) x.id: x};
      versi = (j['versi'] ?? '').toString();
      diperbarui = sekarang;
      diperiksa = sekarang;
      await _simpan();
      final p = j['peringatan'];
      return 'Daftar ruas diperbarui: ${baru.length} ruas.' +
          ((p is List && p.isNotEmpty) ? ' Peringatan: ${p.join('; ')}' : '');
    } on TimeoutException {
      return 'Waktu habis. Coba lagi saat sinyal lebih baik.';
    } on SocketException {
      return 'Tidak ada koneksi internet.';
    } on FormatException {
      return 'Jawaban skrip bukan JSON. Periksa alamat skrip.';
    } catch (e) {
      return 'Gagal memperbarui daftar ruas.';
    } finally {
      sibuk = false;
      notifyListeners();
    }
  }
}
