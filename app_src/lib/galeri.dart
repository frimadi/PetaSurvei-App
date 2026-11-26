import 'dart:io';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

const albumGaleri = 'Survei Jalan';

/// Menyalin foto asli (tanpa tulisan) ke album galeri HP sebagai cadangan petugas.
/// Mengembalikan false bila gagal (mis. izin ditolak); kegagalan tidak boleh menggagalkan foto survei.
Future<bool> simpanKeGaleri(String sumber, String nama) async {
  try {
    final sementara = await getTemporaryDirectory();
    final salinan = await File(sumber).copy('${sementara.path}/$nama');
    try {
      await Gal.putImage(salinan.path, album: albumGaleri);
    } finally {
      try {
        await salinan.delete();
      } catch (_) {}
    }
    return true;
  } catch (_) {
    return false;
  }
}
