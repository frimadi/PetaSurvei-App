import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gudang.dart';
import 'halaman_antrean.dart';
import 'halaman_pengaturan.dart';
import 'daftar_ruas.dart';
import 'halaman_survei.dart';
import 'pengunggah.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final gudang = Gudang();
  await gudang.muat();
  final daftarRuas = DaftarRuas(gudang);
  await daftarRuas.muat();
  runApp(PetaSurveiApp(gudang: gudang, pengunggah: Pengunggah(gudang), daftarRuas: daftarRuas));
}

class PetaSurveiApp extends StatelessWidget {
  final Gudang gudang;
  final Pengunggah pengunggah;
  final DaftarRuas daftarRuas;
  const PetaSurveiApp({super.key, required this.gudang, required this.pengunggah, required this.daftarRuas});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Peta Survei',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2F6F6A)),
        home: Beranda(gudang: gudang, pengunggah: pengunggah, daftarRuas: daftarRuas),
      );
}

class Beranda extends StatefulWidget {
  final Gudang gudang;
  final Pengunggah pengunggah;
  final DaftarRuas daftarRuas;
  const Beranda({super.key, required this.gudang, required this.pengunggah, required this.daftarRuas});

  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> with WidgetsBindingObserver {
  int _tab = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.gudang.addListener(_cek);
    // Coba ulang berkala selama aplikasi terbuka (foto gagal/belum terkirim).
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => widget.pengunggah.kirimSemua());
    widget.pengunggah.kirimSemua();
    widget.daftarRuas.perbaruiOtomatis();
  }

  // Foto baru (status menunggu) langsung dikirim.
  void _cek() {
    if (widget.gudang.daftar.any((t) => t.status == 'menunggu' || (t.ubahTertunda && t.galat.isEmpty))) {
      widget.pengunggah.kirimSemua();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.pengunggah.kirimSemua();
      widget.daftarRuas.perbaruiOtomatis();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.gudang.removeListener(_cek);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Halaman dibangun ulang saat berpindah tab, sehingga kamera dan GPS mati saat tidak dipakai.
    final halaman = [
      HalamanSurvei(gudang: widget.gudang, daftarRuas: widget.daftarRuas),
      HalamanAntrean(gudang: widget.gudang, pengunggah: widget.pengunggah, daftarRuas: widget.daftarRuas),
      HalamanPengaturan(gudang: widget.gudang, daftarRuas: widget.daftarRuas),
    ][_tab];
    return Scaffold(
      body: halaman,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), label: 'Survei'),
          NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: 'Antrean'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Pengaturan'),
        ],
      ),
    );
  }
}
