/// Model dan pencarian daftar ruas SK Jalan (tanpa ketergantungan Flutter).
class Ruas {
  final String id; // ID_GIS, contoh ID-00001 atau IDD-00017
  final String nama; // contoh "Jl Putra Nelayan"
  final String jenis; // K = Jalan Kabupaten, D = Jalan Desa
  final String kec;
  final String desa;
  final String _namaN;
  final String _kunci;

  Ruas(this.id, this.nama, this.jenis, this.kec, this.desa)
      : _namaN = normalisasi(nama),
        _kunci = normalisasi('$nama $kec $desa $id');

  factory Ruas.dari(List<dynamic> a) =>
      Ruas(a[0].toString(), a[1].toString(), a[2].toString(), a[3].toString(), a[4].toString());

  String get jenisLabel => jenis == 'D' ? 'Jalan Desa' : 'Jalan Kabupaten';
  String get keterangan => [jenisLabel, kec, desa, id].where((e) => e.isNotEmpty).join(' · ');
}

/// Huruf kecil, tanpa tanda baca, "jalan" disamakan dengan "jl".
String normalisasi(String s) {
  final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  return t.replaceAll(RegExp(r'\bjalan\b'), 'jl');
}

List<Ruas> uraiRuas(List<dynamic> r) =>
    [for (final a in r) if (a is List && a.length >= 5) Ruas.dari(a)];

class HasilCari {
  final List<Ruas> daftar;
  final int total;
  const HasilCari(this.daftar, this.total);
}

/// Semua kata yang diketik harus ada pada nama, kecamatan, desa, atau ID.
/// Urutan: nama persis, nama diawali, nama memuat, lalu sisanya.
HasilCari cariRuas(List<Ruas> semua, String q, {int batas = 8}) {
  final n = normalisasi(q);
  if (n.length < 2) return const HasilCari([], 0);
  final kata = n.split(' ').where((e) => e.isNotEmpty).toList();
  final hasil = <MapEntry<int, Ruas>>[];
  for (final r in semua) {
    if (!kata.every(r._kunci.contains)) continue;
    int skor;
    if (r._namaN == n || r._namaN == 'jl $n') {
      skor = 0;
    } else if (r._namaN.startsWith(n) || r._namaN.startsWith('jl $n')) {
      skor = 1;
    } else if (r._namaN.contains(n)) {
      skor = 2;
    } else {
      skor = 3;
    }
    hasil.add(MapEntry(skor, r));
  }
  hasil.sort((a, b) {
    final c = a.key.compareTo(b.key);
    if (c != 0) return c;
    final l = a.value.nama.length.compareTo(b.value.nama.length);
    return l != 0 ? l : a.value.nama.compareTo(b.value.nama);
  });
  return HasilCari([for (final e in hasil.take(batas)) e.value], hasil.length);
}
