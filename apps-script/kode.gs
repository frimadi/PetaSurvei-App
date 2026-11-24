/**
 * Perantara unggah foto survei ke Google Drive.
 * Aplikasi/halaman uji mengirim foto + data titik + kode akses petugas.
 * Skrip menyimpan foto ke folder "foto" dan menambah titik ke file sesi di folder "sesi".
 *
 * Skrip ini dibuat dari dalam Google Sheet (Ekstensi > Apps Script).
 * Sheet harus punya tab bernama "Petugas" dengan kolom: kode | nama | aktif (ya/tidak).
 */

const ID_FOLDER = 'ISI_ID_FOLDER_DI_SINI';   // ID folder utama SurveiJalan di Drive
const BATAS_FOTO_MB = 8;

function doGet() {
  return jawab({ ok: true, pesan: 'Skrip aktif. Gunakan POST untuk mengunggah.' });
}

function doPost(e) {
  const kunci = LockService.getScriptLock();
  try {
    const data = JSON.parse(e.postData.contents);
    const petugas = cariPetugas(data.kode);
    if (!petugas) return jawab({ ok: false, pesan: 'Kode tidak valid atau tidak aktif.' });

    // Perubahan data foto yang sudah terunggah (tanpa mengirim ulang fotonya)
    if (data.aksi === 'ubah') return ubahTitik(data, petugas, kunci);

    const t = periksaTitik(data.titik);
    const foto = data.foto || {};
    if (['image/jpeg', 'image/png'].indexOf(foto.mime) < 0) throw new Error('Jenis foto harus JPEG atau PNG.');
    if (typeof foto.dataBase64 !== 'string' || foto.dataBase64.length > BATAS_FOTO_MB * 1.4 * 1024 * 1024) {
      throw new Error('Foto kosong atau terlalu besar.');
    }

    kunci.waitLock(20000);   // cegah dua kiriman menulis file sesi bersamaan
    const induk = DriveApp.getFolderById(ID_FOLDER);
    const folderFoto = subfolder(induk, 'foto');
    const folderSesi = subfolder(induk, 'sesi');

    // 1. Simpan foto (lewati jika sudah ada: pengiriman ulang tidak membuat duplikat)
    const namaFoto = t.id + (foto.mime === 'image/png' ? '.png' : '.jpg');
    if (!folderFoto.getFilesByName(namaFoto).hasNext()) {
      const blob = Utilities.newBlob(Utilities.base64Decode(foto.dataBase64), foto.mime, namaFoto);
      folderFoto.createFile(blob);
    }

    // 2. Tambah titik ke file sesi petugas pada tanggal itu
    const tanggal = t.waktu.substring(0, 10);
    const namaSesi = namaFileSesi(tanggal, petugas.nama);
    const ada = folderSesi.getFilesByName(namaSesi);
    let berkas = ada.hasNext() ? ada.next() : null;
    const sesi = berkas ? JSON.parse(berkas.getBlob().getDataAsString()) : { versi: 1, petugas: petugas.nama, tanggal: tanggal, titik: [] };

    let duplikat = sesi.titik.some(function (x) { return x.id === t.id; });
    if (!duplikat) {
      sesi.titik.push({ id: t.id, foto: namaFoto, lat: t.lat, lon: t.lon, bearing: t.bearing, ruas: t.ruas, sta: t.sta, kondisi: t.kondisi, akurasi: t.akurasi, catatan: t.catatan, waktu: t.waktu });
      const isi = JSON.stringify(sesi, null, 2);
      if (berkas) berkas.setContent(isi); else folderSesi.createFile(namaSesi, isi, MimeType.PLAIN_TEXT);
    }
    return jawab({ ok: true, id: t.id, duplikat: duplikat, sesi: namaSesi });
  } catch (err) {
    return jawab({ ok: false, pesan: String(err.message || err) });
  } finally {
    try { kunci.releaseLock(); } catch (x) {}
  }
}

function namaFileSesi(tanggal, namaPetugas) {
  return tanggal + '_' + namaPetugas.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') + '.json';
}

/**
 * Mengubah data satu titik (nama jalan, STA, kondisi, catatan, arah) di file sesi.
 * Titik dicari lewat id pada file sesi petugas yang sama di tanggal foto diambil.
 * Koordinat, waktu, dan foto tidak diubah.
 */
function ubahTitik(data, petugas, kunci) {
  const t = periksaTitik(data.titik);
  kunci.waitLock(20000);
  const folderSesi = subfolder(DriveApp.getFolderById(ID_FOLDER), 'sesi');
  const namaSesi = namaFileSesi(t.waktu.substring(0, 10), petugas.nama);
  const ada = folderSesi.getFilesByName(namaSesi);
  if (!ada.hasNext()) return jawab({ ok: false, pesan: 'File sesi tidak ditemukan untuk petugas ini.' });
  const berkas = ada.next();
  const sesi = JSON.parse(berkas.getBlob().getDataAsString());
  let x = null;
  for (let i = 0; i < sesi.titik.length; i++) {
    if (sesi.titik[i].id === t.id) { x = sesi.titik[i]; break; }
  }
  if (!x) return jawab({ ok: false, pesan: 'Titik tidak ditemukan di Drive.' });
  x.ruas = t.ruas; x.sta = t.sta; x.kondisi = t.kondisi; x.catatan = t.catatan; x.bearing = t.bearing;
  berkas.setContent(JSON.stringify(sesi, null, 2));
  return jawab({ ok: true, id: t.id, ubah: true, sesi: namaSesi });
}

function cariPetugas(kode) {
  if (typeof kode !== 'string' || kode.length < 8) return null;
  const baris = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Petugas').getDataRange().getValues();
  for (let i = 1; i < baris.length; i++) {
    if (String(baris[i][0]).trim() === kode && String(baris[i][2]).trim().toLowerCase() === 'ya') {
      return { nama: String(baris[i][1]).trim() || 'petugas' };
    }
  }
  return null;
}

function periksaTitik(t) {
  if (!t) throw new Error('Data titik kosong.');
  if (!/^[A-Za-z0-9_-]{6,60}$/.test(t.id || '')) throw new Error('ID titik tidak valid.');
  if (!/^\d{4}-\d{2}-\d{2}T/.test(t.waktu || '')) throw new Error('Format waktu tidak valid.');
  const lat = Number(t.lat), lon = Number(t.lon), bearing = Number(t.bearing);
  if (!(lat >= -90 && lat <= 90) || !(lon >= -180 && lon <= 180)) throw new Error('Koordinat tidak valid.');
  if (!(bearing >= 0 && bearing <= 360)) throw new Error('Arah harus 0-360 derajat.');
  return {
    id: t.id, waktu: t.waktu, lat: lat, lon: lon, bearing: Math.round(bearing),
    ruas: String(t.ruas || '').substring(0, 120), catatan: String(t.catatan || '').substring(0, 300),
    sta: String(t.sta || '').substring(0, 50), kondisi: String(t.kondisi || '').substring(0, 40),
    akurasi: (t.akurasi != null && isFinite(Number(t.akurasi))) ? Math.round(Number(t.akurasi) * 10) / 10 : null
  };
}

function subfolder(induk, nama) {
  const it = induk.getFoldersByName(nama);
  return it.hasNext() ? it.next() : induk.createFolder(nama);
}

function jawab(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

// Jalankan fungsi ini SEKALI dari editor untuk memberi izin akses Drive dan Sheet.
function izinkan() {
  DriveApp.getFolderById(ID_FOLDER).getName();
  SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Petugas').getName();
  Logger.log('Izin OK');
}
