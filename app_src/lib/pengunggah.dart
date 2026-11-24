import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'gudang.dart';

/// Dijalankan di isolate terpisah agar layar tidak macet.
/// Sisi terpanjang dikecilkan ke 1600 px, JPEG kualitas 80.
Uint8List kompresJpeg(Uint8List data) {
  try {
    final asli = img.decodeJpg(data);
    if (asli == null) return data;
    var o = img.bakeOrientation(asli);
    if (o.width >= o.height && o.width > 1600) {
      o = img.copyResize(o, width: 1600, interpolation: img.Interpolation.average);
    } else if (o.height > o.width && o.height > 1600) {
      o = img.copyResize(o, height: 1600, interpolation: img.Interpolation.average);
    }
    return Uint8List.fromList(img.encodeJpg(o, quality: 80));
  } catch (_) {
    return data;
  }
}

class Pengunggah extends ChangeNotifier {
  final Gudang gudang;
  Pengunggah(this.gudang);

  bool sibuk = false;
  String? pesan;

  int get jumlahBelumTerkirim =>
      gudang.daftar.where((t) => t.status != 'terkirim').length;

  /// Foto sudah terkirim, tetapi datanya diubah di HP dan perubahan belum sampai ke Drive.
  int get jumlahUbahTertunda =>
      gudang.daftar.where((t) => t.status == 'terkirim' && t.ubahTertunda).length;

  void _setPesan(String? p) {
    pesan = p;
    notifyListeners();
  }

  Titik? _berikut(Set<String> dicoba) {
    // daftar: terbaru di depan, jadi dibalik agar yang terlama dikirim dulu.
    for (final t in gudang.daftar.reversed) {
      if ((t.status == 'menunggu' || t.status == 'gagal') && !dicoba.contains(t.id)) {
        return t;
      }
    }
    return null;
  }

  Titik? _berikutUbah(Set<String> dicoba) {
    for (final t in gudang.daftar.reversed) {
      if (t.status == 'terkirim' && t.ubahTertunda && !dicoba.contains(t.id)) return t;
    }
    return null;
  }

  String _tandaUbah(Titik t) => '${t.ruas}|${t.sta}|${t.kondisi}|${t.catatan}|${t.bearing}';

  /// Mengirim semua foto berstatus menunggu/gagal, lalu perubahan data foto yang sudah terkirim.
  /// Berhenti pada kegagalan pertama (mis. tanpa sinyal) agar tidak memboroskan baterai.
  Future<void> kirimSemua() async {
    if (sibuk) return;
    final url = gudang.baca('url').trim();
    final kode = gudang.baca('kode').trim();
    if (_berikut({}) == null && _berikutUbah({}) == null) return;
    if (url.isEmpty || kode.isEmpty) {
      _setPesan('Isi alamat skrip dan kode akses di Pengaturan agar foto bisa dikirim.');
      return;
    }
    sibuk = true;
    pesan = null;
    notifyListeners();
    final dicoba = <String>{};
    final dicobaUbah = <String>{};
    try {
      var lanjut = true;
      while (lanjut) {
        final t = _berikut(dicoba);
        if (t == null) break;
        dicoba.add(t.id);
        lanjut = await _kirimSatu(t, url, kode);
      }
      while (lanjut) {
        final t = _berikutUbah(dicobaUbah);
        if (t == null) break;
        dicobaUbah.add(t.id);
        lanjut = await _kirimUbah(t, url, kode);
      }
    } finally {
      sibuk = false;
      notifyListeners();
    }
  }

  Future<bool> _kirimSatu(Titik t, String url, String kode) async {
    final f = File(gudang.jalur(t));
    if (!await f.exists()) {
      t.status = 'gagal';
      t.galat = 'Berkas foto tidak ditemukan di HP';
      await gudang.perbarui();
      return true;
    }
    t.status = 'mengirim';
    t.galat = '';
    await gudang.perbarui();
    try {
      final mentah = await f.readAsBytes();
      final kecil = await compute(kompresJpeg, mentah);
      final badan = jsonEncode({
        'kode': kode,
        'titik': {
          'id': t.id,
          'waktu': t.waktu,
          'lat': t.lat,
          'lon': t.lon,
          'akurasi': t.akurasi,
          'bearing': t.bearing,
          'ruas': t.ruas,
          'sta': t.sta,
          'kondisi': t.kondisi,
          'catatan': t.catatan,
        },
        'foto': {'mime': 'image/jpeg', 'dataBase64': base64Encode(kecil)},
      });
      final j = await _kirim(url, badan);
      if (j['ok'] == true) {
        t.status = 'terkirim';
        t.galat = '';
        await gudang.perbarui();
        return true;
      }
      t.status = 'gagal';
      t.galat = (j['pesan'] ?? j['galat'] ?? 'Ditolak oleh skrip').toString();
      await gudang.perbarui();
      return false;
    } on TimeoutException {
      return await _gagal(t, 'Waktu habis. Sinyal lemah?');
    } on SocketException {
      return await _gagal(t, 'Tidak ada koneksi internet.');
    } on FormatException {
      return await _gagal(t, 'Jawaban skrip bukan JSON. Periksa alamat /exec dan akses "Siapa saja".');
    } catch (e) {
      return await _gagal(t, 'Gagal mengirim.');
    }
  }

  /// Mengirim perubahan data (bukan fotonya) untuk foto yang sudah ada di Drive.
  Future<bool> _kirimUbah(Titik t, String url, String kode) async {
    final tanda = _tandaUbah(t);
    t.galat = '';
    try {
      final badan = jsonEncode({
        'aksi': 'ubah',
        'kode': kode,
        'titik': {
          'id': t.id,
          'waktu': t.waktu,
          'lat': t.lat,
          'lon': t.lon,
          'akurasi': t.akurasi,
          'bearing': t.bearing,
          'ruas': t.ruas,
          'sta': t.sta,
          'kondisi': t.kondisi,
          'catatan': t.catatan,
        },
      });
      final j = await _kirim(url, badan);
      if (j['ok'] == true) {
        // Bila data diubah lagi saat pengiriman berlangsung, tanda tetap menyala.
        if (_tandaUbah(t) == tanda) t.ubahTertunda = false;
        t.galat = '';
        await gudang.perbarui();
        return true;
      }
      var p = (j['pesan'] ?? j['galat'] ?? 'Ditolak oleh skrip').toString();
      if (p.contains('Jenis foto')) {
        p = 'Skrip Apps Script belum diperbarui ke versi baru (perlu deploy Versi baru).';
      }
      return await _gagalUbah(t, p);
    } on TimeoutException {
      return await _gagalUbah(t, 'Waktu habis. Sinyal lemah?');
    } on SocketException {
      return await _gagalUbah(t, 'Tidak ada koneksi internet.');
    } on FormatException {
      return await _gagalUbah(t, 'Jawaban skrip bukan JSON. Periksa alamat /exec dan akses "Siapa saja".');
    } catch (e) {
      return await _gagalUbah(t, 'Gagal mengirim perubahan.');
    }
  }

  Future<bool> _gagalUbah(Titik t, String alasan) async {
    t.galat = alasan;
    await gudang.perbarui();
    return false;
  }

  Future<bool> _gagal(Titik t, String alasan) async {
    t.status = 'gagal';
    t.galat = alasan;
    await gudang.perbarui();
    return false;
  }

  /// Apps Script menjawab POST dengan pengalihan (302). Dart tidak mengikutinya
  /// untuk POST, jadi alamat tujuan diambil manual dengan GET.
  Future<Map<String, dynamic>> _kirim(String url, String badan) async {
    final c = http.Client();
    try {
      final req = http.Request('POST', Uri.parse(url))
        ..followRedirects = false
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..body = badan;
      final terkirim = await c.send(req).timeout(const Duration(seconds: 90));
      var res = await http.Response.fromStream(terkirim);
      var n = 0;
      while (const [301, 302, 303, 307, 308].contains(res.statusCode) && n < 5) {
        final lok = res.headers['location'];
        if (lok == null) break;
        res = await c.get(Uri.parse(lok)).timeout(const Duration(seconds: 60));
        n++;
      }
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map<String, dynamic>) return j;
      return {'ok': false, 'pesan': 'Jawaban skrip tidak dikenali'};
    } finally {
      c.close();
    }
  }
}
