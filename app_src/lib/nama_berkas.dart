/// Nama berkas untuk salinan di galeri, mudah dicari: SJ_20261125_093012_JlPutraNelayan.jpg
String namaBerkasGaleri(String id, String ruas) {
  // id berbentuk 20261125-093012-ab12 (tanggal-jam-acak)
  final bagian = id.split('-');
  final tgl = bagian.isNotEmpty ? bagian[0] : 'tanpa-tanggal';
  final jam = bagian.length > 1 ? bagian[1] : '000000';
  final kata = ruas
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .map((e) => e[0].toUpperCase() + e.substring(1))
      .join();
  final slug = kata.length > 30 ? kata.substring(0, 30) : kata;
  return 'SJ_${tgl}_$jam${slug.isEmpty ? '' : '_$slug'}.jpg';
}
