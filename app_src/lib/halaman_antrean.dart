import 'dart:io';
import 'package:flutter/material.dart';
import 'gudang.dart';

class HalamanAntrean extends StatefulWidget {
  final Gudang gudang;
  const HalamanAntrean({super.key, required this.gudang});

  @override
  State<HalamanAntrean> createState() => _HalamanAntreanState();
}

class _HalamanAntreanState extends State<HalamanAntrean> {
  final Set<String> _pilih = {};

  Color _warna(String s) =>
      s == 'terkirim' ? Colors.green : (s == 'gagal' ? Colors.red : Colors.orange);

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
        subtitle: Text('${formatWaktu(t.waktu)} · ${t.kondisi}'),
        trailing: _pilih.contains(t.id)
            ? const Icon(Icons.check_circle)
            : Text(t.status, style: TextStyle(color: _warna(t.status), fontWeight: FontWeight.w600)),
        onTap: () {
          if (mode) {
            _alih(t.id);
          } else {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => HalamanDetail(gudang: widget.gudang, titik: t)));
          }
        },
        onLongPress: () => _alih(t.id),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.gudang,
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
                  if (lama.isNotEmpty && !mode) _spanduk(lama),
                  for (final t in d) _baris(t, mode),
                ]),
        );
      },
    );
  }
}

class HalamanDetail extends StatefulWidget {
  final Gudang gudang;
  final Titik titik;
  const HalamanDetail({super.key, required this.gudang, required this.titik});

  @override
  State<HalamanDetail> createState() => _HalamanDetailState();
}

class _HalamanDetailState extends State<HalamanDetail> {
  late final _ruas = TextEditingController(text: widget.titik.ruas);
  late final _sta = TextEditingController(text: widget.titik.sta);
  late final _catatan = TextEditingController(text: widget.titik.catatan);
  late final _arah = TextEditingController(text: widget.titik.bearing.toString());
  late String _kondisi = widget.titik.kondisi;

  bool get _kunci => widget.titik.status == 'terkirim';

  @override
  void dispose() {
    _ruas.dispose();
    _sta.dispose();
    _catatan.dispose();
    _arah.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final a = int.tryParse(_arah.text.trim());
    if (a == null || a < 0 || a > 360) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arah harus 0-360.')));
      return;
    }
    final t = widget.titik;
    t.ruas = _ruas.text.trim();
    t.sta = _sta.text.trim();
    t.catatan = _catatan.text.trim();
    t.kondisi = _kondisi;
    t.bearing = a % 360;
    t.arahTerbaca = true;
    await widget.gudang.perbarui();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _hapus() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus foto ini dari HP?'),
        content: Text(_kunci
            ? 'Foto sudah terkirim. Hanya salinan di HP yang dihapus.'
            : 'Foto belum terkirim, jadi akan hilang sepenuhnya.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await widget.gudang.hapus([widget.titik]);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.titik;
    return Scaffold(
      appBar: AppBar(title: Text(formatWaktu(t.waktu))),
      body: ListView(children: [
        SizedBox(
          height: 300,
          child: Container(
            color: Colors.black,
            child: InteractiveViewer(
              child: Image.file(File(widget.gudang.jalur(t)), fit: BoxFit.contain),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Koordinat ${t.lat.toStringAsFixed(6)}, ${t.lon.toStringAsFixed(6)}'
                '${t.akurasi != null ? ' (±${t.akurasi!.round()} m)' : ''}'),
            if (!t.arahTerbaca)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Arah kompas tidak terbaca saat foto diambil. Isi manual.',
                    style: TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 12),
            TextField(
                controller: _ruas,
                enabled: !_kunci,
                decoration: const InputDecoration(labelText: 'Nama jalan', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final k in daftarKondisi)
                ChoiceChip(
                  label: Text(k),
                  selected: _kondisi == k,
                  onSelected: _kunci ? null : (_) => setState(() => _kondisi = k),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _arah,
                      enabled: !_kunci,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Arah (0-360°)', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _sta,
                      enabled: !_kunci,
                      decoration: const InputDecoration(labelText: 'STA', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 10),
            TextField(
                controller: _catatan,
                enabled: !_kunci,
                decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder())),
            if (_kunci)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Data foto ini sudah terkirim dan tidak bisa diubah dari aplikasi.'),
              ),
            const SizedBox(height: 16),
            Row(children: [
              if (!_kunci) Expanded(child: FilledButton(onPressed: _simpan, child: const Text('Simpan'))),
              if (!_kunci) const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: _hapus, child: const Text('Hapus dari HP'))),
            ]),
          ]),
        ),
      ]),
    );
  }
}
