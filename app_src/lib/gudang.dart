import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const daftarKondisi = ['Baik', 'Sedang', 'Rusak ringan', 'Rusak berat', 'Dalam pekerjaan'];

String _dua(int n) => n.toString().padLeft(2, '0');

/// Waktu lokal lengkap dengan zona, contoh 2026-11-23T09:30:12+07:00
String waktuSekarangIso() {
  final d = DateTime.now();
  final z = d.timeZoneOffset;
  final m = z.inMinutes.abs();
  return '${d.year}-${_dua(d.month)}-${_dua(d.day)}T${_dua(d.hour)}:${_dua(d.minute)}:${_dua(d.second)}'
      '${z.isNegative ? '-' : '+'}${_dua(m ~/ 60)}:${_dua(m % 60)}';
}

/// Tampilan untuk pengguna: dd-mm-yyyy jj:mm
String formatWaktu(String iso) {
  if (iso.length < 16) return iso;
  return '${iso.substring(8, 10)}-${iso.substring(5, 7)}-${iso.substring(0, 4)} ${iso.substring(11, 16)}';
}

String buatId(String iso) {
  final acak = Random().nextInt(1679616).toRadixString(36).padLeft(4, '0');
  return '${iso.substring(0, 4)}${iso.substring(5, 7)}${iso.substring(8, 10)}-'
      '${iso.substring(11, 13)}${iso.substring(14, 16)}${iso.substring(17, 19)}-$acak';
}

class Titik {
  final String id;
  final String foto;
  final String waktu;
  double lat;
  double lon;
  double? akurasi;
  int bearing;
  bool arahTerbaca;
  String ruas;
  String sta;
  String kondisi;
  String catatan;
  String status; // menunggu | terkirim | gagal

  Titik({
    required this.id,
    required this.foto,
    required this.waktu,
    required this.lat,
    required this.lon,
    this.akurasi,
    required this.bearing,
    this.arahTerbaca = true,
    required this.ruas,
    this.sta = '',
    required this.kondisi,
    this.catatan = '',
    this.status = 'menunggu',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'foto': foto,
        'waktu': waktu,
        'lat': lat,
        'lon': lon,
        'akurasi': akurasi,
        'bearing': bearing,
        'arahTerbaca': arahTerbaca,
        'ruas': ruas,
        'sta': sta,
        'kondisi': kondisi,
        'catatan': catatan,
        'status': status,
      };

  factory Titik.dari(Map<String, dynamic> j) => Titik(
        id: j['id'] as String,
        foto: j['foto'] as String,
        waktu: j['waktu'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        akurasi: (j['akurasi'] as num?)?.toDouble(),
        bearing: (j['bearing'] as num).toInt(),
        arahTerbaca: (j['arahTerbaca'] as bool?) ?? true,
        ruas: (j['ruas'] as String?) ?? '',
        sta: (j['sta'] as String?) ?? '',
        kondisi: (j['kondisi'] as String?) ?? daftarKondisi.first,
        catatan: (j['catatan'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'menunggu',
      );
}

/// Penyimpanan lokal: daftar foto (titik.json), berkas foto, dan pengaturan.
class Gudang extends ChangeNotifier {
  late Directory _akar;
  late Directory dirFoto;
  late SharedPreferences _p;
  List<Titik> daftar = []; // terbaru di depan

  Future<void> muat() async {
    _p = await SharedPreferences.getInstance();
    _akar = await getApplicationDocumentsDirectory();
    dirFoto = Directory('${_akar.path}/foto');
    if (!await dirFoto.exists()) await dirFoto.create(recursive: true);
    final f = File('${_akar.path}/titik.json');
    if (await f.exists()) {
      final j = jsonDecode(await f.readAsString()) as List;
      daftar = j.map((e) => Titik.dari(e as Map<String, dynamic>)).toList();
    }
  }

  String jalur(Titik t) => '${dirFoto.path}/${t.foto}';

  Future<void> _simpan() async {
    await File('${_akar.path}/titik.json')
        .writeAsString(jsonEncode(daftar.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> tambah(Titik t) async {
    daftar.insert(0, t);
    await _simpan();
  }

  Future<void> perbarui() => _simpan();

  Future<void> hapus(Iterable<Titik> ts) async {
    for (final t in ts.toList()) {
      final f = File(jalur(t));
      if (await f.exists()) await f.delete();
      daftar.remove(t);
    }
    await _simpan();
  }

  String baca(String k, [String d = '']) => _p.getString(k) ?? d;
  Future<void> tulis(String k, String v) => _p.setString(k, v);
}
