/// STA ditulis "KM+MMM" (contoh 1+250). Kolom KM dan Meter dipisah di layar,
/// tetapi yang tersimpan dan terkirim tetap satu teks, sama seperti sebelumnya.
class HasilSta {
  final String teks;
  final String? galat;
  const HasilSta(this.teks, [this.galat]);
}

class PecahanSta {
  final String km;
  final String meter;
  const PecahanSta(this.km, this.meter);
}

/// Kolom meter hanya boleh 0-999. Mengembalikan pesan galat, atau null bila sah/kosong.
String? galatMeter(String meter) {
  final m = meter.trim();
  if (m.isEmpty) return null;
  final n = int.tryParse(m);
  if (n == null || n < 0 || n > 999) return 'Meter 0-999';
  return null;
}

/// Menyusun "KM+MMM". Keduanya kosong -> teks kosong. Salah satu kosong dianggap 0.
HasilSta susunSta(String km, String meter) {
  final k = km.trim(), m = meter.trim();
  if (k.isEmpty && m.isEmpty) return const HasilSta('');
  final kn = k.isEmpty ? 0 : int.tryParse(k);
  final mn = m.isEmpty ? 0 : int.tryParse(m);
  if (kn == null || kn < 0) return const HasilSta('', 'KM harus angka bulat');
  if (mn == null || mn < 0 || mn > 999) return const HasilSta('', 'Meter harus 0-999');
  return HasilSta('$kn+${mn.toString().padLeft(3, '0')}');
}

/// Memecah STA tersimpan ke dua kolom. Kosong -> dua kolom kosong.
/// Mengembalikan null bila teks tidak berpola "KM+MMM" (misalnya catatan bebas).
PecahanSta? pecahSta(String sta) {
  final s = sta.trim();
  if (s.isEmpty) return const PecahanSta('', '');
  final m = RegExp(r'^(\d+)\s*\+\s*(\d{1,3})$').firstMatch(s);
  if (m == null) return null;
  return PecahanSta(int.parse(m.group(1)!).toString(), int.parse(m.group(2)!).toString());
}
