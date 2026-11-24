import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gudang.dart';
import 'halaman_antrean.dart';
import 'halaman_pengaturan.dart';
import 'halaman_survei.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final gudang = Gudang();
  await gudang.muat();
  runApp(PetaSurveiApp(gudang: gudang));
}

class PetaSurveiApp extends StatelessWidget {
  final Gudang gudang;
  const PetaSurveiApp({super.key, required this.gudang});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Peta Survei',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2F6F6A)),
        home: Beranda(gudang: gudang),
      );
}

class Beranda extends StatefulWidget {
  final Gudang gudang;
  const Beranda({super.key, required this.gudang});

  @override
  State<Beranda> createState() => _BerandaState();
}

class _BerandaState extends State<Beranda> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // Halaman dibangun ulang saat berpindah tab, sehingga kamera dan GPS mati saat tidak dipakai.
    final halaman = [
      HalamanSurvei(gudang: widget.gudang),
      HalamanAntrean(gudang: widget.gudang),
      HalamanPengaturan(gudang: widget.gudang),
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
