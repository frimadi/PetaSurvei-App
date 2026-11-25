import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'daftar_ruas.dart';
import 'gudang.dart';
import 'halaman_antrean.dart';
import 'kompas.dart';
import 'pilih_ruas.dart';
import 'sta.dart';

class HalamanSurvei extends StatefulWidget {
  final Gudang gudang;
  final DaftarRuas daftarRuas;
  const HalamanSurvei({super.key, required this.gudang, required this.daftarRuas});

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
  final _km = TextEditingController();
  final _meter = TextEditingController();
  String _idRuas = '';
  final _catatan = TextEditingController();
  final _petugas = TextEditingController();
  String _kondisi = daftarKondisi.first;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ruas.text = widget.gudang.baca('ruas');
    _idRuas = _ruas.text.isEmpty ? '' : widget.gudang.baca('idRuas');
    _petugas.text = widget.gudang.baca('petugas');
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
    _km.dispose();
    _meter.dispose();
    _catatan.dispose();
    _petugas.dispose();
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
      _bukaIsian();
      return;
    }
    final sta = susunSta(_km.text, _meter.text);
    if (sta.galat != null) {
      _pesan('STA: ${sta.galat}');
      _bukaIsian();
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
    // Layar terkunci potret, jadi kamera diberi tahu posisi HP saat ini
    // (potret/lanskap) agar foto tersimpan dengan orientasi yang benar.
    final posisiHp = _kompas.orientasi;
    try {
      try {
        await k.lockCaptureOrientation(posisiHp);
      } catch (_) {}
      final x = await k.takePicture();
      try {
        await k.unlockCaptureOrientation();
      } catch (_) {}
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
        idRuas: _idRuas,
        sta: sta.teks,
        kondisi: _kondisi,
        catatan: _catatan.text.trim(),
        petugas: _petugas.text.trim(),
      );
      await widget.gudang.tambah(t);
      await widget.gudang.tulis('ruas', t.ruas);
      await widget.gudang.tulis('idRuas', t.idRuas);
      await widget.gudang.tulis('kondisi', t.kondisi);
      await widget.gudang.tulis('petugas', t.petugas);
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

  /// Pratinjau utuh sesuai bentuk asli kamera (tidak dipotong), tanpa ditimpa kontrol.
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
    // previewSize berbentuk lanskap (sensor), layar aplikasi potret: rasio dibalik.
    // buildPreview dipakai langsung (bukan CameraPreview) agar pratinjau tidak ikut
    // berputar saat orientasi foto dikunci untuk jepretan lanskap.
    return Center(
      child: AspectRatio(
        aspectRatio: 1 / k.value.aspectRatio,
        child: k.buildPreview(),
      ),
    );
  }

  Widget _chip(String teks, Color warna, {IconData? ikon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (ikon != null) ...[Icon(ikon, size: 14, color: Colors.white), const SizedBox(width: 4)],
          Text(teks, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      );

  /// Panel isian (nama jalan, kondisi, STA, catatan) yang naik dari bawah.
  Future<void> _bukaIsian() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) {
        final mq = MediaQuery.of(c);
        // Ruang di bawah: papan ketik bila terbuka, bila tidak maka bilah navigasi Android.
        final bawah = math.max(mq.viewInsets.bottom, mq.viewPadding.bottom);
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bawah),
          child: StatefulBuilder(
            builder: (c, setS) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PilihRuas(
                    daftar: widget.daftarRuas,
                    controller: _ruas,
                    idRuas: _idRuas,
                    autofocus: _ruas.text.trim().isEmpty,
                    onId: (v) {
                      setS(() {});
                      setState(() => _idRuas = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final k in daftarKondisi)
                        ChoiceChip(
                          label: Text(k),
                          selected: _kondisi == k,
                          onSelected: (_) {
                            setS(() {});
                            setState(() => _kondisi = k);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: TextField(
                        controller: _km,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                            labelText: 'STA KM (opsional)', border: OutlineInputBorder()),
                      ),
                    ),
                    const Padding(
                        padding: EdgeInsets.fromLTRB(8, 14, 8, 0), child: Text('+', style: TextStyle(fontSize: 22))),
                    Expanded(
                      child: TextField(
                        controller: _meter,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setS(() {}),
                        decoration: InputDecoration(
                            labelText: 'Meter',
                            hintText: '0-999',
                            border: const OutlineInputBorder(),
                            errorText: galatMeter(_meter.text)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _catatan,
                    decoration:
                        const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _petugas,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Nama petugas (opsional)',
                        helperText: 'Diingat untuk foto berikutnya',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Selesai')),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  /// Miniatur foto terakhir membuka detailnya; dari sana bisa digeser ke foto lain.
  Future<void> _bukaDetail() async {
    final semua = List<Titik>.of(widget.gudang.daftar);
    if (semua.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              HalamanDetail(gudang: widget.gudang, daftarRuas: widget.daftarRuas, daftar: semua, awal: 0)),
    );
    if (mounted) setState(() {});
  }

  Widget _panelBawah(Titik? terakhir) {
    final kosong = _ruas.text.trim().isEmpty;
    final ringkas = [
      kosong ? 'Isi nama jalan' : _ruas.text.trim(),
      _kondisi,
      if (susunSta(_km.text, _meter.text).teks.isNotEmpty) 'STA ${susunSta(_km.text, _meter.text).teks}',
    ].join(' · ');
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _bukaIsian,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: kosong ? Colors.red : Colors.black26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(_idRuas.isNotEmpty ? Icons.check_circle : Icons.edit_outlined,
                  size: 20, color: kosong ? Colors.red : (_idRuas.isNotEmpty ? Colors.green : null)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(ringkas,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: kosong ? Colors.red : null)),
              ),
              const Icon(Icons.expand_less),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: terakhir == null ? null : _bukaDetail,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: terakhir == null
                    ? Container(color: Colors.black12, child: const Icon(Icons.photo_outlined))
                    : Image.file(File(widget.gudang.jalur(terakhir)),
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                        errorBuilder: (_, __, ___) => Container(color: Colors.black12, child: const Icon(Icons.broken_image))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _sibuk ? null : _ambil,
                icon: const Icon(Icons.camera_alt),
                label: Text(_sibuk ? 'Menyimpan…' : 'Ambil foto'),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.gudang.daftar;
    final terakhir = d.isEmpty ? null : d.first;
    final akurasi = _pos?.accuracy;
    final arah = _kompas.arah;
    final warnaGps = akurasi == null
        ? Colors.grey
        : (akurasi <= 10 ? Colors.green : (akurasi <= 20 ? Colors.orange : Colors.red));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _pratinjau(),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        _chip(
                            akurasi == null
                                ? (_galatGps ?? 'Mencari GPS…')
                                : 'GPS ±${akurasi.round()} m',
                            warnaGps),
                        _chip(arah == null ? 'Arah —' : 'Arah ${arah.round()}°', Colors.blueGrey),
                        _chip(_kompas.lanskap ? 'Foto lanskap' : 'Foto potret', Colors.black54,
                            ikon: Icons.screen_rotation),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            _panelBawah(terakhir),
          ],
        ),
      ),
    );
  }
}
