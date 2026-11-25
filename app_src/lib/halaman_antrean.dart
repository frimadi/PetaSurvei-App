import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'daftar_ruas.dart';
import 'gudang.dart';
import 'pengunggah.dart';
import 'pilih_ruas.dart';
import 'sta.dart';

class HalamanAntrean extends StatefulWidget {
  final Gudang gudang;
  final Pengunggah pengunggah;
  final DaftarRuas daftarRuas;
  const HalamanAntrean({super.key, required this.gudang, required this.pengunggah, required this.daftarRuas});

  @override
  State<HalamanAntrean> createState() => _HalamanAntreanState();
}

class _HalamanAntreanState extends State<HalamanAntrean> {
  final Set<String> _pilih = {};

  Color _warna(String s) => s == 'terkirim'
      ? Colors.green
      : (s == 'gagal' ? Colors.red : (s == 'mengirim' ? Colors.blue : Colors.orange));

  List<Titik> _lama(List<Titik> d) {
    final hari = int.tryParse(widget.gudang.baca('hari', '7')) ?? 7;
    final batas = DateTime.now().subtract(Duration(days: hari));
    return d
        .where((t) => t.status == 'terkirim' && (DateTime.tryParse(t.waktu)?.isBefore(batas) ?? false))
        .toList();
  }

  Future<void> _hapus(List<Titik> d) async {
    final target = d.where((t) => _pilih.contains(t.id)).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus ${target.length} foto dari HP?'),
        content: const Text('Hanya salinan di HP yang dihapus. Foto di Drive tidak ikut terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await widget.gudang.hapus(target);
      if (mounted) setState(_pilih.clear);
    }
  }

  Widget _statusKirim() {
    final p = widget.pengunggah;
    final n = p.jumlahBelumTerkirim;
    final u = p.jumlahUbahTertunda;
    if (!p.sibuk && n == 0 && u == 0 && p.pesan == null) return const SizedBox.shrink();
    final ringkas = [
      if (n > 0) '$n foto belum terkirim',
      if (u > 0) '$u perubahan belum terkirim',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ListTile(
        leading: p.sibuk
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Icon(Icons.cloud_upload_outlined),
        title: Text(p.sibuk ? 'Mengirim…' : (ringkas.isEmpty ? 'Semua terkirim' : ringkas)),
        subtitle: p.pesan != null ? Text(p.pesan!) : null,
        trailing: p.sibuk ? null : TextButton(onPressed: p.kirimSemua, child: const Text('Kirim')),
      ),
    );
  }

  void _alih(String id) => setState(() {
        if (!_pilih.remove(id)) _pilih.add(id);
      });

  Widget _spanduk(List<Titik> lama) {
    final hari = widget.gudang.baca('hari', '7');
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: Text('${lama.length} foto terkirim berusia lebih dari $hari hari'),
        subtitle: const Text('Bersihkan untuk menghemat ruang HP?'),
        trailing: TextButton(
          onPressed: () => setState(() => _pilih.addAll(lama.map((t) => t.id))),
          child: const Text('Pilih'),
        ),
      ),
    );
  }

  Widget _baris(Titik t, bool mode) => ListTile(
        selected: _pilih.contains(t.id),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(File(widget.gudang.jalur(t)),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              cacheWidth: 160,
              errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56, child: Icon(Icons.broken_image))),
        ),
        title: Text(t.ruas),
        subtitle: Text(
            (t.status == 'gagal' || t.ubahTertunda) && t.galat.isNotEmpty
                ? '${formatWaktu(t.waktu)} · ${t.galat}'
                : '${formatWaktu(t.waktu)} · ${t.kondisi}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        trailing: _pilih.contains(t.id)
            ? const Icon(Icons.check_circle)
            : (t.status == 'terkirim' && t.ubahTertunda)
                ? Text(t.galat.isNotEmpty ? 'ubah gagal' : 'ubah menunggu',
                    style: TextStyle(
                        color: t.galat.isNotEmpty ? Colors.red : Colors.orange, fontWeight: FontWeight.w600))
                : Text(t.status, style: TextStyle(color: _warna(t.status), fontWeight: FontWeight.w600)),
        onTap: () {
          if (mode) {
            _alih(t.id);
          } else {
            final semua = List<Titik>.of(widget.gudang.daftar);
            final ix = semua.indexOf(t);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        HalamanDetail(
                        gudang: widget.gudang,
                        daftarRuas: widget.daftarRuas,
                        daftar: semua,
                        awal: ix < 0 ? 0 : ix)));
          }
        },
        onLongPress: () => _alih(t.id),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.gudang, widget.pengunggah]),
      builder: (context, _) {
        final d = widget.gudang.daftar;
        _pilih.removeWhere((id) => !d.any((t) => t.id == id));
        final mode = _pilih.isNotEmpty;
        final bolehHapus = mode && _pilih.every((id) => d.firstWhere((t) => t.id == id).status == 'terkirim');
        final lama = _lama(d);
        return Scaffold(
          appBar: mode
              ? AppBar(
                  leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_pilih.clear)),
                  title: Text('${_pilih.length} dipilih'),
                  actions: [
                    IconButton(
                      tooltip: bolehHapus ? 'Hapus dari HP' : 'Hanya foto terkirim yang bisa dihapus',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: bolehHapus ? () => _hapus(d) : null,
                    ),
                  ],
                )
              : AppBar(title: const Text('Antrean dan riwayat')),
          body: d.isEmpty
              ? const Center(child: Text('Belum ada foto.'))
              : ListView(children: [
                  if (!mode) _statusKirim(),
                  if (lama.isNotEmpty && !mode) _spanduk(lama),
                  for (final t in d) _baris(t, mode),
                ]),
        );
      },
    );
  }
}

/// Kumpulan isian satu foto di layar detail (disimpan agar tidak hilang saat digeser).
class _Isian {
  final TextEditingController ruas, catatan, arah, km, meter, petugas;
  String kondisi;
  String idRuas;
  final String staLama; // STA tersimpan yang tidak berpola KM+MMM (ditampilkan sebagai catatan)
  String kmAwal, meterAwal;
  _Isian(Titik t)
      : ruas = TextEditingController(text: t.ruas),
        catatan = TextEditingController(text: t.catatan),
        petugas = TextEditingController(text: t.petugas),
        arah = TextEditingController(text: t.bearing.toString()),
        km = TextEditingController(text: pecahSta(t.sta)?.km ?? ''),
        meter = TextEditingController(text: pecahSta(t.sta)?.meter ?? ''),
        kondisi = t.kondisi,
        idRuas = t.idRuas,
        staLama = pecahSta(t.sta) == null ? t.sta : '',
        kmAwal = pecahSta(t.sta)?.km ?? '',
        meterAwal = pecahSta(t.sta)?.meter ?? '';

  void buang() {
    ruas.dispose();
    catatan.dispose();
    petugas.dispose();
    arah.dispose();
    km.dispose();
    meter.dispose();
  }
}

/// Detail foto. Bisa digeser ke foto sebelumnya/berikutnya dalam daftar.
/// Semua kolom bisa diubah; untuk foto yang sudah terkirim, perubahan dikirim ulang
/// ke Drive (hanya datanya, bukan fotonya).
class HalamanDetail extends StatefulWidget {
  final Gudang gudang;
  final DaftarRuas daftarRuas;
  final List<Titik> daftar;
  final int awal;
  const HalamanDetail(
      {super.key, required this.gudang, required this.daftarRuas, required this.daftar, required this.awal});

  @override
  State<HalamanDetail> createState() => _HalamanDetailState();
}

class _HalamanDetailState extends State<HalamanDetail> {
  late final List<Titik> _d = List<Titik>.of(widget.daftar);
  late final PageController _pc = PageController(initialPage: widget.awal);
  final Map<String, _Isian> _isian = {};
  late String _aktif = _d[widget.awal].id;

  _Isian _ambil(Titik t) => _isian.putIfAbsent(t.id, () => _Isian(t));

  Titik? _cari(String id) {
    for (final t in _d) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  void dispose() {
    _pc.dispose();
    for (final i in _isian.values) {
      i.buang();
    }
    super.dispose();
  }

  void _pesan(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  /// Menyimpan isian foto [id] bila ada yang berubah. Mengembalikan false bila isian tidak sah.
  Future<bool> _simpanId(String id, {bool tampilPesan = true}) async {
    final t = _cari(id);
    final i = _isian[id];
    if (t == null || i == null) return true;
    if (!widget.gudang.daftar.contains(t)) return true;
    void galat(String pesan) {
      if (tampilPesan && mounted) _pesan('Perubahan tidak disimpan: $pesan');
    }

    final ruas = i.ruas.text.trim();
    final cat = i.catatan.text.trim();
    final pet = i.petugas.text.trim();
    final a = int.tryParse(i.arah.text.trim());
    final staBerubah = i.km.text.trim() != i.kmAwal || i.meter.text.trim() != i.meterAwal;
    final sta = susunSta(i.km.text, i.meter.text);
    if (staBerubah && sta.galat != null) {
      galat(sta.galat!);
      return false;
    }
    final staBaru = staBerubah ? sta.teks : t.sta;
    final idBaru = ruas.isEmpty ? '' : i.idRuas;
    final sama = ruas == t.ruas &&
        idBaru == t.idRuas &&
        staBaru == t.sta &&
        cat == t.catatan &&
        pet == t.petugas &&
        i.kondisi == t.kondisi &&
        a != null &&
        a % 360 == t.bearing;
    if (sama) return true;
    if (a == null || a < 0 || a > 360) {
      galat('arah harus 0-360.');
      return false;
    }
    if (ruas.isEmpty) {
      galat('nama jalan tidak boleh kosong.');
      return false;
    }
    if (a % 360 != t.bearing) t.arahTerbaca = true;
    t.ruas = ruas;
    t.idRuas = idBaru;
    t.sta = staBaru;
    t.catatan = cat;
    t.petugas = pet;
    t.kondisi = i.kondisi;
    t.bearing = a % 360;
    i.kmAwal = i.km.text.trim();
    i.meterAwal = i.meter.text.trim();
    // Foto yang sudah ada di Drive: tandai agar perubahannya ikut dikirim.
    if (t.status == 'terkirim' || t.status == 'mengirim') {
      t.ubahTertunda = true;
      t.galat = '';
    }
    await widget.gudang.perbarui();
    return true;
  }

  Future<void> _simpanTombol() async {
    final t = _cari(_aktif);
    if (t == null) return;
    final ok = await _simpanId(_aktif);
    if (ok && mounted) {
      final kirim = t.status == 'terkirim' || t.status == 'mengirim';
      _pesan(kirim ? 'Tersimpan. Perubahan akan dikirim ke Drive.' : 'Tersimpan.');
    }
  }

  Future<void> _ganti(int indeks) async {
    if (indeks < 0 || indeks >= _d.length) return;
    final lama = _aktif;
    _aktif = _d[indeks].id;
    await _simpanId(lama);
    if (mounted) setState(() {});
  }

  Future<void> _hapus() async {
    final t = _cari(_aktif);
    if (t == null) return;
    final kunci = t.status == 'terkirim' || t.status == 'mengirim';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus foto ini dari HP?'),
        content: Text(kunci
            ? 'Hanya salinan di HP yang dihapus. Foto di Drive tidak ikut terhapus.'
            : 'Foto belum terkirim, jadi akan hilang sepenuhnya.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final idx = _d.indexOf(t);
    await widget.gudang.hapus([t]);
    if (!mounted) return;
    _d.removeAt(idx);
    if (_d.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final baru = idx >= _d.length ? _d.length - 1 : idx;
    _aktif = _d[baru].id;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pc.hasClients) _pc.jumpToPage(baru);
    });
  }

  String _ketStatus(Titik t) {
    if (t.status == 'terkirim') {
      if (!t.ubahTertunda) return 'Sudah terkirim ke Drive.';
      return t.galat.isNotEmpty
          ? 'Perubahan gagal dikirim: ${t.galat}'
          : 'Perubahan menunggu dikirim ke Drive.';
    }
    if (t.status == 'mengirim') return 'Sedang dikirim…';
    if (t.status == 'gagal') return 'Gagal dikirim: ${t.galat}';
    return 'Menunggu dikirim.';
  }

  Widget _halaman(Titik t) {
    final i = _ambil(t);
    final berkas = File(widget.gudang.jalur(t));
    return ListView(key: ValueKey(t.id), children: [
      GestureDetector(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => _FotoPenuh(berkas: berkas))),
        child: Container(
          height: 300,
          color: Colors.black,
          alignment: Alignment.center,
          child: Image.file(berkas,
              fit: BoxFit.contain,
              cacheWidth: 1200,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Koordinat ${t.lat.toStringAsFixed(6)}, ${t.lon.toStringAsFixed(6)}'
              '${t.akurasi != null ? ' (±${t.akurasi!.round()} m)' : ''}'),
          const SizedBox(height: 4),
          Text(_ketStatus(t),
              style: TextStyle(
                  color: (t.galat.isNotEmpty && (t.status == 'gagal' || t.ubahTertunda))
                      ? Colors.red
                      : Colors.black54)),
          if (!t.arahTerbaca)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Arah kompas tidak terbaca saat foto diambil. Isi manual.',
                  style: TextStyle(color: Colors.orange)),
            ),
          const SizedBox(height: 12),
          PilihRuas(
            daftar: widget.daftarRuas,
            controller: i.ruas,
            idRuas: i.idRuas,
            onId: (v) => setState(() => i.idRuas = v),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final k in daftarKondisi)
              ChoiceChip(
                label: Text(k),
                selected: i.kondisi == k,
                onSelected: (_) => setState(() => i.kondisi = k),
              ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                flex: 2,
                child: TextField(
                    controller: i.arah,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Arah (°)', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(
                child: TextField(
                    controller: i.km,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'STA KM', border: OutlineInputBorder()))),
            const Padding(
                padding: EdgeInsets.fromLTRB(6, 14, 6, 0), child: Text('+', style: TextStyle(fontSize: 22))),
            Expanded(
                child: TextField(
                    controller: i.meter,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                        labelText: 'Meter', border: const OutlineInputBorder(), errorText: galatMeter(i.meter.text)))),
          ]),
          if (i.staLama.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('STA lama (teks bebas): ${i.staLama}. Isi KM dan Meter untuk menggantinya.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
          const SizedBox(height: 10),
          TextField(
              controller: i.catatan,
              decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: i.petugas,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama petugas (opsional)', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: FilledButton(onPressed: _simpanTombol, child: const Text('Simpan'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: _hapus, child: const Text('Hapus dari HP'))),
          ]),
          const SizedBox(height: 24),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final indeks = _d.indexWhere((t) => t.id == _aktif);
    final t = indeks >= 0 ? _d[indeks] : _d.first;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _simpanId(_aktif, tampilPesan: false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatWaktu(t.waktu)),
            Text('${(indeks < 0 ? 0 : indeks) + 1} dari ${_d.length} · geser untuk foto lain',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ]),
        ),
        body: AnimatedBuilder(
          animation: widget.gudang,
          builder: (context, _) => PageView.builder(
            controller: _pc,
            itemCount: _d.length,
            onPageChanged: _ganti,
            itemBuilder: (context, i) => _halaman(_d[i]),
          ),
        ),
      ),
    );
  }
}

/// Foto layar penuh, bisa diperbesar dengan dua jari.
class _FotoPenuh extends StatelessWidget {
  final File berkas;
  const _FotoPenuh({required this.berkas});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Image.file(berkas, fit: BoxFit.contain, cacheWidth: 2400),
          ),
        ),
      );
}
