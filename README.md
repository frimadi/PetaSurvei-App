# Peta Survei - Aplikasi Android (tahap 1)

Aplikasi Flutter untuk mengambil foto survei jalan dengan koordinat GPS, arah kompas, nama jalan, STA, dan kondisi.
Tahap 1: foto disimpan di HP dan bisa dilihat/diubah/dihapus. Unggah ke Drive (Apps Script) menyusul di tahap 2.

## Cara membangun APK (tanpa Flutter di laptop)
1. Buat repo GitHub baru (misalnya `PetaSurvei-App`) dan unggah seluruh isi folder ini, termasuk folder `.github`, `app_src`, dan `tool`.
   Jika folder `.github` tidak ikut terunggah, buat file `.github/workflows/build-apk.yml` lewat *Add file > Create new file* lalu tempel isinya.
2. Buka tab **Actions**. Proses *Build APK* berjalan otomatis (atau pilih *Run workflow*).
3. Setelah hijau, buka prosesnya, lalu unduh **peta-survei-apk** di bagian *Artifacts* (berkas ZIP berisi `app-release.apk`).
4. Ekstrak, kirim APK ke HP, lalu pasang (izinkan "instal dari sumber tidak dikenal").

Jika proses gagal (merah), salin pesan galat dari langkah yang gagal dan kirim ke Claude untuk diperbaiki.

## Struktur
- `app_src/lib` : kode Dart. `app_src/pubspec.yaml` : daftar paket.
- `tool/patch_manifest.py` : menambah izin kamera, lokasi, internet ke AndroidManifest saat build.
- Kerangka Android dibuat otomatis oleh workflow (`flutter create`), jadi tidak ada di repo.
