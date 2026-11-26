import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'daftar_ruas.dart';
import 'gudang.dart';
import 'halaman_tentang.dart';
import 'info_app.dart';

class HalamanPengaturan extends StatefulWidget {
  final Gudang gudang;
  final DaftarRuas daftarRuas;
  const HalamanPengaturan({super.key, required this.gudang, required this.daftarRuas});

  @override
  State<HalamanPengaturan> createState() => _HalamanPengaturanState();
}

class _HalamanPengaturanState extends State<HalamanPengaturan> {
  Gudang get g => widget.gudang;
  late final _url = TextEditingController(text: g.baca('url'));
  late final _kode = TextEditingController(text: g.baca('kode'));
  late bool _tulisan = g.baca('tulisan', '0') == '1';
  late bool _galeri = g.baca('galeri', '1') == '1';
  late String _ukuran = g.baca('ukuran', 'Sedang');
  late String _hari = g.baca('hari', '7');
  String? _hasil;
  bool _menguji = false;
  String? _hasilRuas;

  @override
  void dispose() {
    _url.dispose();
    _kode.dispose();
    super.dispose();
  }

  Future<void> _uji() async {
    final u = _url.text.trim();
    if (u.isEmpty) {
      setState(() => _hasil = 'Isi alamat skrip dulu.');
      return;
    }
    setState(() {
      _menguji = true;
      _hasil = 'Menguji…';
    });
    try {
      final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 20));
      final j = jsonDecode(r.body);
      setState(() => _hasil = (j is Map && j['ok'] == true)
          ? 'Terhubung: skrip aktif.'
          : 'Skrip menjawab, tetapi bukan jawaban yang diharapkan.');
    } catch (e) {
      setState(() => _hasil = 'Gagal terhubung. Periksa alamat dan koneksi.');
    } finally {
      if (mounted) setState(() => _menguji = false);
    }
  }

  Future<void> _perbaruiRuas() async {
    setState(() => _hasilRuas = 'Memperbarui…');
    final p = await widget.daftarRuas.perbarui(paksa: true);
    if (mounted) setState(() => _hasilRuas = p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Tentang aplikasi dan panduan'),
            subtitle: const Text('Fungsi, cara pakai, versi, developer'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HalamanTentang())),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
              labelText: 'Alamat skrip (berakhiran /exec)', border: OutlineInputBorder()),
          onChanged: (v) => g.tulis('url', v.trim()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _kode,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Kode akses petugas', border: OutlineInputBorder()),
          onChanged: (v) => g.tulis('kode', v.trim()),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(onPressed: _menguji ? null : _uji, child: const Text('Uji koneksi')),
        ),
        if (_hasil != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_hasil!)),
        const Divider(height: 32),
        const Text('Daftar ruas SK Jalan', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: widget.daftarRuas,
          builder: (context, _) {
            final d = widget.daftarRuas;
            final info = d.kosong
                ? 'Belum diunduh.'
                : '${d.semua.length} ruas · diperbarui ${d.diperbarui.length >= 10 ? formatWaktu(d.diperbarui) : '-'}';
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(info, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: d.sibuk ? null : _perbaruiRuas,
                child: Text(d.sibuk ? 'Memperbarui…' : 'Perbarui daftar ruas'),
              ),
            ]);
          },
        ),
        if (_hasilRuas != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_hasilRuas!)),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Simpan juga ke galeri'),
          subtitle: const Text('Foto asli disalin ke album "Survei Jalan" di galeri HP sebagai cadangan. Bila Google Foto aktif, foto dapat ikut tercadang ke akun Google di HP ini.'),
          value: _galeri,
          onChanged: (v) {
            setState(() => _galeri = v);
            g.tulis('galeri', v ? '1' : '0');
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tulisan pada foto'),
          subtitle: const Text('Nama jalan, koordinat, arah, waktu, dan petugas ditempel pada foto saat dikirim ke Drive. Foto asli di HP dan galeri tetap tanpa tulisan.'),
          value: _tulisan,
          onChanged: (v) {
            setState(() => _tulisan = v);
            g.tulis('tulisan', v ? '1' : '0');
          },
        ),
        const SizedBox(height: 8),
        const Text('Ukuran huruf tulisan'),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Kecil', label: Text('Kecil')),
            ButtonSegment(value: 'Sedang', label: Text('Sedang')),
            ButtonSegment(value: 'Besar', label: Text('Besar')),
          ],
          selected: {_ukuran},
          onSelectionChanged: (s) {
            setState(() => _ukuran = s.first);
            g.tulis('ukuran', s.first);
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _hari,
          decoration: const InputDecoration(
              labelText: 'Ingatkan foto terkirim setelah (hari)', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: '3', child: Text('3 hari')),
            DropdownMenuItem(value: '7', child: Text('7 hari')),
            DropdownMenuItem(value: '14', child: Text('14 hari')),
            DropdownMenuItem(value: '30', child: Text('30 hari')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _hari = v);
            g.tulis('hari', v);
          },
        ),
        const SizedBox(height: 24),
        Text('$namaAplikasi v$versiAplikasi',
            style: const TextStyle(color: Colors.grey)),
      ]),
    );
  }
}
