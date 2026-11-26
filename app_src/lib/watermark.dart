import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Tulisan pada foto (watermark) memakai font bitmap bawaan paket `image`.
/// Setiap baris digambar dengan arial48, lalu diperkecil sesuai ukuran pilihan
/// (proporsional terhadap lebar foto) agar tampil halus.

/// Tinggi huruf sebagai bagian dari lebar foto: Kecil 2,2%, Sedang 3%, Besar 4%.
double pecahanUkuran(String ukuran) {
  switch (ukuran) {
    case 'Kecil':
      return 0.022;
    case 'Besar':
      return 0.04;
    default:
      return 0.03;
  }
}

/// Hanya karakter yang ada di font; selain itu diganti agar tidak hilang diam-diam.
String bersihkanTeks(String s) {
  final b = StringBuffer();
  for (final c in s.runes) {
    if (c >= 32 && c < 127) {
      b.writeCharCode(c);
    } else if (c == 0xB7 || c == 0x2022) {
      b.write('|');
    } else {
      b.write('?');
    }
  }
  return b.toString();
}

int lebarTeks(img.BitmapFont f, String s) {
  var w = 0;
  for (final c in s.codeUnits) {
    final ch = f.characters[c];
    w += ch != null ? ch.xAdvance : f.base ~/ 2;
  }
  return w;
}

/// Memotong teks bila terlalu panjang untuk lebar [maks] (pada skala font asli).
String potongMuat(img.BitmapFont f, String s, int maks) {
  if (lebarTeks(f, s) <= maks) return s;
  var t = s;
  while (t.length > 1 && lebarTeks(f, '$t...') > maks) {
    t = t.substring(0, t.length - 1);
  }
  return '$t...';
}

/// Menempel [baris] (maksimal beberapa baris) di bagian bawah [o] di atas pita gelap.
/// Mengubah [o] langsung dan mengembalikannya.
img.Image tempelTulisan(img.Image o, List<String> baris, String ukuran) {
  final teks = baris.map(bersihkanTeks).where((e) => e.trim().isNotEmpty).toList();
  if (teks.isEmpty) return o;
  final font = img.arial48;
  final tinggiTarget = (o.width * pecahanUkuran(ukuran)).clamp(14.0, 120.0);
  final skala = tinggiTarget / font.lineHeight;
  final margin = (tinggiTarget * 0.7).round();
  final lebarMaks = ((o.width - 2 * margin) / skala).floor();

  // Gambar tiap baris pada kanvas transparan, lalu perkecil.
  final potongan = <img.Image>[];
  for (final s in teks) {
    final t = potongMuat(font, s, lebarMaks);
    final w = lebarTeks(font, t) + 8;
    final kanvas = img.Image(width: w, height: font.lineHeight, numChannels: 4);
    img.drawString(kanvas, t, font: font, x: 4, y: 0, color: img.ColorRgba8(255, 255, 255, 255));
    final lebarBaru = (w * skala).round().clamp(1, o.width);
    final tinggiBaru = (font.lineHeight * skala).round().clamp(1, o.height);
    potongan.add(img.copyResize(kanvas,
        width: lebarBaru, height: tinggiBaru, interpolation: img.Interpolation.average));
  }

  final tinggiBaris = potongan.first.height;
  final jarak = (tinggiBaris * 0.18).round();
  final pad = (tinggiBaris * 0.55).round();
  final tinggiPita = potongan.length * tinggiBaris + (potongan.length - 1) * jarak + 2 * pad;
  final y0 = (o.height - tinggiPita).clamp(0, o.height);

  // Pita gelap semi-transparan (piksel digelapkan ke 35%).
  for (final p in o) {
    if (p.y >= y0) {
      p
        ..r = p.r * 0.35
        ..g = p.g * 0.35
        ..b = p.b * 0.35;
    }
  }
  var y = y0 + pad;
  for (final p in potongan) {
    img.compositeImage(o, p, dstX: margin - (4 * skala).round(), dstY: y);
    y += tinggiBaris + jarak;
  }
  return o;
}

/// Isi tulisan untuk satu foto. [waktuIso] contoh 2026-11-25T09:30:12+07:00 (jam lokal tersimpan).
List<String> susunBaris({
  required String ruas,
  required String idRuas,
  required double lat,
  required double lon,
  required int bearing,
  required String waktuIso,
  required String petugas,
}) {
  final nama = ruas.trim().isEmpty ? '(Jalan tidak diisi)' : ruas.trim();
  final b1 = idRuas.isEmpty ? nama : '$nama ($idRuas)';
  final b2 = '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)} | Arah $bearing deg';
  final w = waktuIso.length >= 19 ? waktuIso.substring(0, 19).replaceFirst('T', ' ') : waktuIso;
  final b3 = petugas.trim().isEmpty ? w : '$w | ${petugas.trim()}';
  return [b1, b2, b3];
}

/// Dijalankan di isolate: kompres (sisi terpanjang 1600 px, JPEG 80), lalu tempel tulisan bila diminta.
/// Isi [p]: data (Uint8List), baris (List<String>?), ukuran (String).
Uint8List kompresDenganTulisan(Map<String, dynamic> p) {
  final data = p['data'] as Uint8List;
  try {
    final asli = img.decodeJpg(data);
    if (asli == null) return data;
    var o = img.bakeOrientation(asli);
    if (o.width >= o.height && o.width > 1600) {
      o = img.copyResize(o, width: 1600, interpolation: img.Interpolation.average);
    } else if (o.height > o.width && o.height > 1600) {
      o = img.copyResize(o, height: 1600, interpolation: img.Interpolation.average);
    }
    final baris = p['baris'] as List<String>?;
    if (baris != null && baris.isNotEmpty) {
      o = tempelTulisan(o, baris, (p['ukuran'] as String?) ?? 'Sedang');
    }
    return Uint8List.fromList(img.encodeJpg(o, quality: 80));
  } catch (_) {
    return data;
  }
}
