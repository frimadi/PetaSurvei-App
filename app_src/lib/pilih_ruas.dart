import 'package:flutter/material.dart';
import 'daftar_ruas.dart';
import 'ruas_model.dart';

/// Kolom nama jalan dengan saran dari daftar ruas SK Jalan.
/// Memilih saran mengisi nama dan ID_GIS; mengetik sendiri tetap boleh (ditandai "di luar SK").
class PilihRuas extends StatefulWidget {
  final DaftarRuas daftar;
  final TextEditingController controller;
  final String idRuas; // ID terpilih, kosong bila diketik manual
  final ValueChanged<String> onId;
  final bool autofocus;
  const PilihRuas({
    super.key,
    required this.daftar,
    required this.controller,
    required this.idRuas,
    required this.onId,
    this.autofocus = false,
  });

  @override
  State<PilihRuas> createState() => _PilihRuasState();
}

class _PilihRuasState extends State<PilihRuas> {
  final _fokus = FocusNode();
  String _namaTerpilih = '';
  String? _pesanUnduh;

  @override
  void initState() {
    super.initState();
    if (widget.idRuas.isNotEmpty) _namaTerpilih = widget.controller.text;
    widget.controller.addListener(_berubah);
    _fokus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_berubah);
    _fokus.dispose();
    super.dispose();
  }

  void _berubah() {
    // Teks diubah pengguna setelah memilih: ID dilepas, jadi nama manual.
    if (widget.idRuas.isNotEmpty && widget.controller.text != _namaTerpilih) widget.onId('');
    if (mounted) setState(() {});
  }

  void _pilih(Ruas r) {
    _namaTerpilih = r.nama;
    widget.controller.text = r.nama;
    widget.controller.selection = TextSelection.collapsed(offset: r.nama.length);
    widget.onId(r.id);
    _fokus.unfocus();
  }

  Future<void> _unduh() async {
    final p = await widget.daftar.perbarui(paksa: true);
    if (mounted) setState(() => _pesanUnduh = p);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.daftar,
      builder: (context, _) {
        final teks = widget.controller.text;
        final terpilih = widget.idRuas.isNotEmpty && teks == _namaTerpilih;
        final tampilSaran = _fokus.hasFocus && !terpilih && teks.trim().length >= 2 && !widget.daftar.kosong;
        final hasil = tampilSaran ? cariRuas(widget.daftar.semua, teks) : const HasilCari([], 0);
        final ruas = terpilih ? widget.daftar.cariId(widget.idRuas) : null;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: widget.controller,
            focusNode: _fokus,
            autofocus: widget.autofocus,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nama jalan (cari dari SK)',
              border: const OutlineInputBorder(),
              suffixIcon: teks.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Hapus',
                      onPressed: () {
                        widget.controller.clear();
                        widget.onId('');
                      },
                    ),
            ),
          ),
          if (hasil.daftar.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                for (final r in hasil.daftar)
                  ListTile(
                    dense: true,
                    title: Text(r.nama),
                    subtitle: Text(r.keterangan),
                    onTap: () => _pilih(r),
                  ),
                if (hasil.total > hasil.daftar.length)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('${hasil.total - hasil.daftar.length} hasil lain. Ketik lebih lengkap untuk menyaring.',
                        style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ),
              ]),
            )
          else if (tampilSaran)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Tidak ada ruas SK yang cocok. Nama yang diketik tetap bisa dipakai.',
                  style: TextStyle(color: Colors.black54, fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: terpilih
                ? Row(children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(ruas != null ? ruas.keterangan : 'ID ${widget.idRuas}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54))),
                  ])
                : (teks.trim().isNotEmpty
                    ? const Text('Di luar SK (nama diketik manual)',
                        style: TextStyle(fontSize: 12, color: Colors.orange))
                    : const SizedBox.shrink()),
          ),
          if (widget.daftar.kosong)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(_pesanUnduh ?? 'Daftar ruas SK belum diunduh. ',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                TextButton(
                  onPressed: widget.daftar.sibuk ? null : _unduh,
                  child: Text(widget.daftar.sibuk ? 'Mengunduh…' : 'Unduh sekarang'),
                ),
              ]),
            ),
        ]);
      },
    );
  }
}
