import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'gudang.dart';
import 'kompas.dart';

class HalamanSurvei extends StatefulWidget {
  final Gudang gudang;
  const HalamanSurvei({super.key, required this.gudang});

  @override
  State<HalamanSurvei> createState() => _HalamanSurveiState();
}

class _HalamanSurveiState extends State<HalamanSurvei> with WidgetsBindingObserver {
  CameraController? _kam;
  bool _membuka = false;
  String? _galatKamera, _galatGps;
  StreamSubscription<Position>? _gpsSub;
  Position? _pos;
  final _kompas = Kompas();
  Timer? _timer;
  final _ruas = TextEditingController();
  final _sta = TextEditingController();
  final _catatan = TextEditingController();
  String _kondisi = daftarKondisi.first;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ruas.text = widget.gudang.baca('ruas');
    final k = widget.gudang.baca('kondisi');
    if (daftarKondisi.contains(k)) _kondisi = k;
    _kompas.mulai();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() {});
    });
    _mulaiGps();
    _mulaiKamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _gpsSub?.cancel();
    _kompas.henti();
    _kam?.dispose();
    _ruas.dispose();
    _sta.dispose();
    _catatan.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      final k = _kam;
      _kam = null;
      k?.dispose();
      if (mounted) setState(() {});
    } else if (s == AppLifecycleState.resumed && _kam == null) {
      _mulaiKamera();
    }
  }

  Future<void> _mulaiGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _galatGps = 'GPS HP belum aktif');
        return;
      }
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        if (mounted) setState(() => _galatGps = 'Izin lokasi ditolak');
        return;
      }
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0),
      ).listen((p) {
        if (mounted) setState(() => _pos = p);
      }, onError: (e) {
        if (mounted) setState(() => _galatGps = 'GPS bermasalah');
      });
    } catch (e) {
      if (mounted) setState(() => _galatGps = 'GPS bermasalah');
    }
  }

  Future<void> _mulaiKamera() async {
    if (_membuka) return;
    _membuka = true;
    try {
      final daftar = await availableCameras();
      if (daftar.isEmpty) throw Exception('Tidak ada kamera');
      final cam = daftar.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => daftar.first,
      );
      final k = CameraController(cam, ResolutionPreset.veryHigh,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await k.initialize();
      if (!mounted) {
        await k.dispose();
        return;
      }
      setState(() {
        _kam = k;
        _galatKamera = null;
      });
    } catch (e) {
      if (mounted) setState(() => _galatKamera = 'Kamera tidak bisa dibuka. Periksa izin kamera.');
    } finally {
      _membuka = false;
    }
  }

  void _pesan(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<bool> _konfirmasiAkurasi(double a) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Akurasi GPS kurang baik'),
        content: Text('Akurasi saat ini sekitar ${a.round()} m. Tunggu sebentar agar lebih tepat, atau tetap ambil foto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Tunggu')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tetap ambil')),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _ambil() async {
    final k = _kam;
    if (k == null || !k.value.isInitialized || k.value.isTakingPicture || _sibuk) return;
    if (_ruas.text.trim().isEmpty) {
      _pesan('Isi nama jalan dulu.');
      return;
    }
    if (_pos == null) {
      _pesan('Lokasi belum didapat. Tunggu sebentar.');
      return;
    }
    if (_pos!.accuracy > 20 && !await _konfirmasiAkurasi(_pos!.accuracy)) return;
    setState(() => _sibuk = true);
    // Posisi, arah, dan waktu dicatat tepat saat foto diambil.
    final pos = _pos!;
    final arah = _kompas.arah;
    final waktu = waktuSekarangIso();
    try {
      final x = await k.takePicture();
      final id = buatId(waktu);
      final nama = '$id.jpg';
      await File(x.path).copy('${widget.gudang.dirFoto.path}/$nama');
      try {
        await File(x.path).delete();
      } catch (_) {}
      final t = Titik(
        id: id,
        foto: nama,
        waktu: waktu,
        lat: pos.latitude,
        lon: pos.longitude,
        akurasi: pos.accuracy,
        bearing: ((arah ?? 0).round()) % 360,
        arahTerbaca: arah != null,
        ruas: _ruas.text.trim(),
        sta: _sta.text.trim(),
        kondisi: _kondisi,
        catatan: _catatan.text.trim(),
      );
      await widget.gudang.tambah(t);
      await widget.gudang.tulis('ruas', t.ruas);
      await widget.gudang.tulis('kondisi', t.kondisi);
      if (mounted) {
        _catatan.clear();
        _pesan('Foto tersimpan di HP.');
      }
    } catch (e) {
      if (mounted) _pesan('Gagal mengambil foto.');
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Widget _pratinjau() {
    final k = _kam;
    if (k == null || !k.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_galatKamera ?? 'Membuka kamera…',
              style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        ),
      );
    }
    final u = k.value.previewSize!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: u.height, height: u.width, child: CameraPreview(k)),
      ),
    );
  }

  Widget _chip(String teks, Color warna) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(12)),
        child: Text(teks, style: const TextStyle(color: Colors.white, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final tinggi = MediaQuery.of(context).size.height * 0.42;
    final d = widget.gudang.daftar;
    final terakhir = d.isEmpty ? null : d.first;
    final akurasi = _pos?.accuracy;
    final arah = _kompas.arah;
    final warnaGps = akurasi == null
        ? Colors.grey
        : (akurasi <= 10 ? Colors.green : (akurasi <= 20 ? Colors.orange : Colors.red));
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SizedBox(
              height: tinggi,
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _pratinjau(),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Wrap(spacing: 6, children: [
                        _chip(
                            akurasi == null
                                ? (_galatGps ?? 'Mencari GPS…')
                                : 'GPS ±${akurasi.round()} m',
                            warnaGps),
                        _chip(arah == null ? 'Arah —' : 'Arah ${arah.round()}°', Colors.blueGrey),
                      ]),
                    ),
                    if (terakhir != null)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(File(widget.gudang.jalur(terakhir)),
                              width: 64, height: 64, fit: BoxFit.cover, cacheWidth: 200),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _ruas,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nama jalan', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final k in daftarKondisi)
                        ChoiceChip(
                          label: Text(k),
                          selected: _kondisi == k,
                          onSelected: (_) => setState(() => _kondisi = k),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _sta,
                        decoration: const InputDecoration(
                            labelText: 'STA (opsional)', hintText: '1+250', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _catatan,
                        decoration: const InputDecoration(
                            labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _sibuk ? null : _ambil,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_sibuk ? 'Menyimpan…' : 'Ambil foto'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
