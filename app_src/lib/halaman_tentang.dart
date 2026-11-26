import 'package:flutter/material.dart';
import 'info_app.dart';

/// Tentang aplikasi: fungsi, cara pakai, versi, dan developer.
class HalamanTentang extends StatelessWidget {
  const HalamanTentang({super.key});

  Widget _judul(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6),
        child: Text(t, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _langkah(int n, String judul, String isi) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 12, child: Text('$n', style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$judul. ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: isi),
            ])),
          ),
        ]),
      );

  Widget _baris(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(v)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final warna = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang aplikasi')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: warna.primary, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.add_road, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(namaAplikasi, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Text('Survei kondisi jalan dengan foto, lokasi, dan arah'),
            ]),
          ),
        ]),
        _judul(context, 'Fungsi'),
        const Text(
            'Aplikasi untuk petugas lapangan mendokumentasikan kondisi ruas jalan. Setiap foto disimpan '
            'bersama koordinat GPS, arah kamera (derajat), waktu, nama ruas dari SK Jalan, STA, kondisi, '
            'dan catatan. Foto dikirim ke Google Drive dan ditampilkan di website peta survei seperti '
            'galeri foto berarah.'),
        _judul(context, 'Cara menggunakan'),
        _langkah(1, 'Atur sambungan',
            'Buka Pengaturan, isi alamat skrip (berakhiran /exec) dan kode akses petugas dari admin. '
            'Tekan Uji koneksi, lalu Perbarui daftar ruas.'),
        _langkah(2, 'Siapkan lokasi',
            'Izinkan kamera dan lokasi. Tunggu chip GPS berwarna hijau (akurasi sampai 10 m) sebelum memotret.'),
        _langkah(3, 'Isi data',
            'Di tab Survei, ketuk kotak isian di bawah. Ketik nama jalan lalu pilih dari saran (muncul tanda centang '
            'dan ID ruas). Jalan di luar SK boleh diketik manual. Pilih kondisi, isi STA (KM + meter) bila ada, '
            'catatan, dan nama petugas (semua opsional). Nama petugas diingat untuk foto berikutnya.'),
        _langkah(4, 'Ambil foto',
            'Arahkan kamera sesuai arah jalan yang disurvei, lalu tekan Ambil foto. Foto potret atau lanskap '
            'mengikuti posisi HP saat memotret.'),
        _langkah(5, 'Kirim',
            'Foto dikirim otomatis saat aplikasi terbuka dan ada sinyal. Pantau di tab Antrean: menunggu, '
            'mengirim, terkirim, atau gagal. Foto gagal dicoba lagi tiap 2 menit.'),
        _langkah(6, 'Periksa dan ubah',
            'Di Antrean, ketuk foto untuk melihat detail dan geser ke foto lain. Semua isian bisa diubah, termasuk '
            'foto yang sudah terkirim (perubahan ikut dikirim ke Drive). Tahan foto untuk memilih dan menghapus dari HP.'),
        _judul(context, 'Catatan penting'),
        const Text(
            '• Foto asli juga disalin ke album "Survei Jalan" di galeri HP (bisa dimatikan di Pengaturan). Hapus dari HP di aplikasi tidak menghapus salinan galeri maupun foto di Drive.\n'
            '• Tulisan pada foto (nama jalan, koordinat, arah, waktu, petugas) bisa dinyalakan di Pengaturan. Tulisan hanya ada pada foto yang dikirim ke Drive dan tidak ikut berubah bila data diedit kemudian.\n'
            '• Pengiriman hanya berjalan saat aplikasi terbuka.\n'
            '• Arah kompas bisa meleset di dekat logam atau kabel; jauhkan HP dari benda tersebut saat memotret.\n'
            '• Bila akurasi GPS di atas 20 m, aplikasi akan menanyakan apakah tetap ingin memotret.\n'
            '• Foto di website dapat dilihat siapa saja yang memiliki tautannya; hindari memotret wajah dan plat nomor dari dekat.'),
        _judul(context, 'Informasi aplikasi'),
        _baris('Nama', namaAplikasi),
        _baris('Versi', '$versiAplikasi (build $nomorBuild)'),
        _baris('Developer', namaDeveloper),
        _baris('Unit', '$unitDeveloper, Dinas PU Kabupaten Kotawaringin Timur'),
        _baris('Data', 'Foto dan data survei disimpan di Google Drive dinas melalui Google Apps Script.'),
      ]),
    );
  }
}
