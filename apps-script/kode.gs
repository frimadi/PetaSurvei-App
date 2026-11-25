/**
 * Perantara unggah foto survei ke Google Drive.
 * Aplikasi/halaman uji mengirim foto + data titik + kode akses petugas.
 * Skrip menyimpan foto ke folder "foto" dan menambah titik ke file sesi di folder "sesi".
 *
 * Skrip ini dibuat dari dalam Google Sheet (Ekstensi > Apps Script).
 * Sheet harus punya tab bernama "Petugas" dengan kolom: kode | nama | aktif (ya/tidak).
 * Untuk admin website: tab "Admin" dengan kolom user | sandi | aktif | peran (admin / editor).
 * Tab "Admin" dibuat dengan menjalankan siapkanAdmin() sekali dari editor skrip.
 * Versi 0.6: kolom petugas pada titik, login admin, ubah dan hapus foto dari website.
 */

const ID_FOLDER = '1e81Z8d6-zO5rN2xWbpSYBJLMH5r3vt0Z';   // ID folder utama SurveiJalan di Drive
const BATAS_FOTO_MB = 8;
const MAKS_GAGAL = 5;          // gagal login berturut-turut sebelum dikunci
const KUNCI_DETIK = 900;       // lama kunci login (15 menit)
const MASA_TOKEN_DETIK = 21600; // login admin berlaku 6 jam (batas CacheService)

function doGet(e) {
  const p = (e && e.parameter) || {};
  if (p.aksi === 'daftar') {
    try {
      return jawab(daftarSemua(p.segarkan === '1'));
    } catch (err) {
      return jawab({ ok: false, pesan: String(err.message || err) });
    }
  }
  if (p.aksi === 'ruas') {
    try {
      return jawab(daftarRuas(String(p.versi || '')));
    } catch (err) {
      return jawab({ ok: false, pesan: String(err.message || err) });
    }
  }
  return jawab({ ok: true, pesan: 'Skrip aktif. Gunakan POST untuk mengunggah.' });
}

function teks(v) { return v === null || v === undefined ? '' : String(v).trim(); }

/**
 * Daftar ruas SK Jalan untuk pilihan nama jalan di aplikasi.
 * Membaca berkas GeoJSON di folder "referensi" (di dalam folder utama). Berkas yang namanya
 * memuat kata "desa" dianggap SK Jalan Desa; selain itu SK Jalan Kabupaten.
 * Hanya atribut yang perlu diambil (tanpa geometri), sehingga hasilnya kecil.
 * Untuk memperbarui daftar: ganti berkas GeoJSON di Drive, lalu tekan "Perbarui daftar ruas" di aplikasi.
 * Bila versi dari aplikasi sama dengan versi berkas saat ini, skrip hanya menjawab {sama:true}.
 */
function daftarRuas(versiKlien) {
  const induk = DriveApp.getFolderById(ID_FOLDER);
  const dRef = cariSubfolder(induk, 'referensi');
  if (!dRef) return { ok: false, pesan: 'Folder "referensi" belum ada di folder utama Drive.' };
  const berkas = [];
  const it = dRef.getFiles();
  while (it.hasNext()) {
    const f = it.next();
    if (/\.(geojson|json)$/i.test(f.getName())) berkas.push(f);
  }
  if (!berkas.length) return { ok: false, pesan: 'Folder "referensi" kosong. Unggah berkas GeoJSON SK Jalan.' };
  berkas.sort(function (a, b) { return a.getName() < b.getName() ? -1 : 1; });
  const mentah = berkas.map(function (f) { return f.getName() + ':' + f.getSize() + ':' + f.getLastUpdated().getTime(); }).join('|');
  const versi = Utilities.base64EncodeWebSafe(Utilities.computeDigest(Utilities.DigestAlgorithm.MD5, mentah)).substring(0, 12);
  if (versiKlien && versiKlien === versi) return { ok: true, versi: versi, sama: true };

  const cache = CacheService.getScriptCache();
  const n = Number(cache.get('ruas_n_' + versi) || 0);
  if (n > 0) {
    const bagian = [];
    for (let i = 0; i < n; i++) {
      const b = cache.get('ruas_' + versi + '_' + i);
      if (b === null) break;
      bagian.push(b);
    }
    if (bagian.length === n) return JSON.parse(bagian.join(''));
  }

  const daftar = [], sudah = {}, peringatan = [];
  berkas.forEach(function (f) {
    const nama = f.getName();
    const jenis = /desa/i.test(nama) ? 'D' : 'K';
    let gj;
    try { gj = JSON.parse(f.getBlob().getDataAsString()); }
    catch (e) { peringatan.push(nama + ': bukan JSON yang valid'); return; }
    let dipakai = 0;
    (gj.features || []).forEach(function (ft) {
      const p = ft.properties || {};
      const id = teks(p.ID_GIS);
      const nm = teks(p.NAMA_JL) || teks(p.Nm_Ruas) || teks(p.NAMA_RUAS_);
      if (!id || !nm || sudah[id]) return;
      sudah[id] = true;
      const kec = teks(p.kecamatan) || teks(p.KEC2);
      const desa = teks(p.Desa_Kel) || teks(p.DESA_KELUR) || teks(p.DesKel);
      daftar.push([id, nm, jenis, kec, desa]);
      dipakai++;
    });
    if (!dipakai) peringatan.push(nama + ': tidak ada fitur dengan ID_GIS dan NAMA_JL');
  });
  const hasil = { ok: true, versi: versi, dibuat: new Date().toISOString(), r: daftar, peringatan: peringatan };
  try {
    const t = JSON.stringify(hasil), pecah = [];
    for (let i = 0; i < t.length; i += 50000) pecah.push(t.substring(i, i + 50000));
    const kv = {};
    kv['ruas_n_' + versi] = String(pecah.length);
    pecah.forEach(function (b, i) { kv['ruas_' + versi + '_' + i] = b; });
    cache.putAll(kv, 21600);
  } catch (e) {}   // terlalu besar untuk cache: tidak apa-apa
  return hasil;
}

/**
 * Untuk website penampil (opsi B): menggabungkan semua file sesi dan menambahkan
 * fotoId (ID file foto di Drive) ke tiap titik. Hasil disimpan di cache 10 menit;
 * cache dihapus setiap ada unggahan atau perubahan data. Tambahkan &segarkan=1 untuk memaksa baca ulang.
 */
function daftarSemua(segarkan) {
  const cache = CacheService.getScriptCache();
  if (!segarkan) {
    const n = Number(cache.get('daftar_n') || 0);
    if (n > 0) {
      const bagian = [];
      for (let i = 0; i < n; i++) {
        const b = cache.get('daftar_' + i);
        if (b === null) break;
        bagian.push(b);
      }
      if (bagian.length === n) return JSON.parse(bagian.join(''));
    }
  }
  const induk = DriveApp.getFolderById(ID_FOLDER);
  const idFoto = {};
  const dFoto = cariSubfolder(induk, 'foto');
  if (dFoto) {
    const it = dFoto.getFiles();
    while (it.hasNext()) { const f = it.next(); idFoto[f.getName()] = f.getId(); }
  }
  const sesi = [];
  const dSesi = cariSubfolder(induk, 'sesi');
  if (dSesi) {
    const it = dSesi.getFiles();
    while (it.hasNext()) {
      const f = it.next();
      if (!/\.json$/i.test(f.getName())) continue;
      try {
        const s = JSON.parse(f.getBlob().getDataAsString());
        (s.titik || []).forEach(function (t) { t.fotoId = idFoto[t.foto] || null; });
        sesi.push(s);
      } catch (x) {}
    }
  }
  const hasil = { ok: true, dibuat: new Date().toISOString(), sesi: sesi };
  try {
    const teks = JSON.stringify(hasil), pecah = [];
    for (let i = 0; i < teks.length; i += 50000) pecah.push(teks.substring(i, i + 50000));
    const kv = { daftar_n: String(pecah.length) };
    pecah.forEach(function (b, i) { kv['daftar_' + i] = b; });
    cache.putAll(kv, 600);
  } catch (x) {}   // terlalu besar untuk cache: tidak apa-apa
  return hasil;
}

function hapusCache() {
  try { CacheService.getScriptCache().remove('daftar_n'); } catch (x) {}
}

function cariSubfolder(induk, nama) {
  const it = induk.getFoldersByName(nama);
  return it.hasNext() ? it.next() : null;
}

function doPost(e) {
  const kunci = LockService.getScriptLock();
  try {
    const data = JSON.parse(e.postData.contents);

    // --- Aksi admin dari website (login, ubah, hapus) ---
    if (data.aksi === 'masuk') return masuk(data);
    if (data.aksi === 'admin_ubah' || data.aksi === 'admin_hapus') {
      const adm = cekToken(data.token);
      if (!adm) return jawab({ ok: false, habis: true, pesan: 'Sesi login habis. Silakan masuk lagi.' });
      if (data.aksi === 'admin_hapus' && adm.peran !== 'admin') {
        return jawab({ ok: false, pesan: 'Peran Anda tidak boleh menghapus foto.' });
      }
      return data.aksi === 'admin_ubah' ? adminUbah(data, adm, kunci) : adminHapus(data, adm, kunci);
    }

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
      sesi.titik.push({ id: t.id, foto: namaFoto, lat: t.lat, lon: t.lon, bearing: t.bearing, ruas: t.ruas, idRuas: t.idRuas, sta: t.sta, kondisi: t.kondisi, akurasi: t.akurasi, catatan: t.catatan, petugas: t.petugas, waktu: t.waktu });
      const isi = JSON.stringify(sesi, null, 2);
      if (berkas) berkas.setContent(isi); else folderSesi.createFile(namaSesi, isi, MimeType.PLAIN_TEXT);
    }
    hapusCache();
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
  x.ruas = t.ruas; x.idRuas = t.idRuas; x.sta = t.sta; x.kondisi = t.kondisi; x.catatan = t.catatan; x.bearing = t.bearing; x.petugas = t.petugas;
  berkas.setContent(JSON.stringify(sesi, null, 2));
  hapusCache();
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
    petugas: String(t.petugas || '').substring(0, 60),
    ruas: String(t.ruas || '').substring(0, 120), idRuas: String(t.idRuas || '').substring(0, 30), catatan: String(t.catatan || '').substring(0, 300),
    sta: String(t.sta || '').substring(0, 50), kondisi: String(t.kondisi || '').substring(0, 40),
    akurasi: (t.akurasi != null && isFinite(Number(t.akurasi))) ? Math.round(Number(t.akurasi) * 10) / 10 : null
  };
}

// =====================================================================
// ADMIN WEBSITE: login, ubah, hapus
// Tab "Admin": user | sandi | aktif (ya/tidak) | peran (admin = ubah+hapus, editor = ubah saja)
// Sandi boleh diketik biasa di Sheet; pada login berhasil berikutnya skrip menggantinya dengan hash.
// Untuk mengganti sandi: ketik sandi baru (teks biasa) di kolom sandi.
// =====================================================================

function heks(bytes) {
  return bytes.map(function (b) { return ('0' + (b & 0xff).toString(16)).slice(-2); }).join('');
}

function hashSandi(sandi, garam) {
  return heks(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, garam + ':' + sandi, Utilities.Charset.UTF_8));
}

function bandingkan(a, b) {   // perbandingan teks tanpa berhenti di karakter pertama yang beda
  if (a.length !== b.length) return false;
  let r = 0;
  for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}

function masuk(data) {
  const user = teks(data.user).toLowerCase();
  const sandi = String(data.sandi === null || data.sandi === undefined ? '' : data.sandi);
  if (!user || !sandi) return jawab({ ok: false, pesan: 'Isi user dan kata sandi.' });
  const cache = CacheService.getScriptCache();
  const kg = 'gagal_' + user.replace(/[^a-z0-9_.-]/g, '').substring(0, 40);
  if (Number(cache.get(kg) || 0) >= MAKS_GAGAL) {
    return jawab({ ok: false, pesan: 'Terlalu banyak percobaan gagal. Coba lagi sekitar 15 menit lagi.' });
  }
  const sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Admin');
  if (!sh) return jawab({ ok: false, pesan: 'Tab "Admin" belum ada. Jalankan siapkanAdmin() dari editor skrip.' });
  const baris = sh.getDataRange().getValues();
  for (let i = 1; i < baris.length; i++) {
    if (teks(baris[i][0]).toLowerCase() !== user) continue;
    if (teks(baris[i][2]).toLowerCase() !== 'ya') break;
    const simpan = String(baris[i][1] === null || baris[i][1] === undefined ? '' : baris[i][1]).trim();
    if (!simpan) break;
    let cocok = false;
    if (simpan.indexOf('h1:') === 0) {
      const bagian = simpan.split(':');
      cocok = bagian.length === 3 && bandingkan(bagian[2], hashSandi(sandi, bagian[1]));
    } else {
      cocok = bandingkan(simpan, sandi);
      if (cocok) {   // sandi masih teks biasa: ganti dengan hash
        const garam = Utilities.getUuid().replace(/-/g, '').substring(0, 12);
        const sel = sh.getRange(i + 1, 2);
        sel.setNumberFormat('@');
        sel.setValue('h1:' + garam + ':' + hashSandi(sandi, garam));
      }
    }
    if (!cocok) break;
    cache.remove(kg);
    const peran = teks(baris[i][3]).toLowerCase() === 'editor' ? 'editor' : 'admin';
    const token = Utilities.getUuid().replace(/-/g, '') + Utilities.getUuid().replace(/-/g, '');
    cache.put('tok_' + token, JSON.stringify({ user: teks(baris[i][0]), peran: peran }), MASA_TOKEN_DETIK);
    catatLog(teks(baris[i][0]), 'masuk', '', '');
    return jawab({ ok: true, token: token, user: teks(baris[i][0]), peran: peran, berlaku: MASA_TOKEN_DETIK });
  }
  cache.put(kg, String(Number(cache.get(kg) || 0) + 1), KUNCI_DETIK);
  return jawab({ ok: false, pesan: 'User atau kata sandi salah.' });
}

function cekToken(token) {
  if (typeof token !== 'string' || token.length < 40) return null;
  const v = CacheService.getScriptCache().get('tok_' + token);
  return v ? JSON.parse(v) : null;
}

function catatLog(user, aksi, id, rincian) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sh = ss.getSheetByName('Log');
    if (!sh) {
      sh = ss.insertSheet('Log');
      sh.appendRow(['waktu', 'user', 'aksi', 'id', 'rincian']);
    }
    sh.appendRow([new Date(), user, aksi, id, String(rincian || '').substring(0, 4000)]);
  } catch (x) {}
}

/** Mencari titik berdasarkan id. Memeriksa file sesi bertanggal sama dulu, lalu semua file sesi. */
function cariTitikSesi(folderSesi, id, tanggal) {
  const berkasList = [], lain = [];
  const it = folderSesi.getFiles();
  while (it.hasNext()) {
    const f = it.next();
    if (!/\.json$/i.test(f.getName())) continue;
    (tanggal && f.getName().indexOf(tanggal) === 0 ? berkasList : lain).push(f);
  }
  const urut = berkasList.concat(lain);
  for (let k = 0; k < urut.length; k++) {
    let sesi;
    try { sesi = JSON.parse(urut[k].getBlob().getDataAsString()); } catch (x) { continue; }
    const arr = sesi.titik || [];
    for (let i = 0; i < arr.length; i++) {
      if (arr[i].id === id) return { berkas: urut[k], sesi: sesi, indeks: i };
    }
  }
  return null;
}

/** Admin mengubah data satu titik (ruas, ID ruas, STA, kondisi, catatan, arah, petugas). */
function adminUbah(data, adm, kunci) {
  const t = periksaTitik(data.titik);
  kunci.waitLock(20000);
  const folderSesi = subfolder(DriveApp.getFolderById(ID_FOLDER), 'sesi');
  const h = cariTitikSesi(folderSesi, t.id, t.waktu.substring(0, 10));
  if (!h) return jawab({ ok: false, pesan: 'Titik tidak ditemukan di Drive.' });
  const x = h.sesi.titik[h.indeks];
  const sebelum = JSON.stringify({ ruas: x.ruas, idRuas: x.idRuas, sta: x.sta, kondisi: x.kondisi, catatan: x.catatan, bearing: x.bearing, petugas: x.petugas || '' });
  x.ruas = t.ruas; x.idRuas = t.idRuas; x.sta = t.sta; x.kondisi = t.kondisi; x.catatan = t.catatan; x.bearing = t.bearing; x.petugas = t.petugas;
  h.berkas.setContent(JSON.stringify(h.sesi, null, 2));
  hapusCache();
  catatLog(adm.user, 'ubah', t.id, 'sebelum: ' + sebelum);
  return jawab({ ok: true, id: t.id, ubah: true });
}

/** Admin menghapus titik: dikeluarkan dari file sesi, foto dipindah ke folder "sampah" (bisa dipulihkan). */
function adminHapus(data, adm, kunci) {
  const id = teks(data.id);
  if (!/^[A-Za-z0-9_-]{6,60}$/.test(id)) return jawab({ ok: false, pesan: 'ID titik tidak valid.' });
  kunci.waitLock(20000);
  const induk = DriveApp.getFolderById(ID_FOLDER);
  const folderSesi = subfolder(induk, 'sesi');
  const tanggal = /^\d{4}-\d{2}-\d{2}/.test(teks(data.waktu)) ? teks(data.waktu).substring(0, 10) : '';
  const h = cariTitikSesi(folderSesi, id, tanggal);
  if (!h) return jawab({ ok: false, pesan: 'Titik tidak ditemukan di Drive (mungkin sudah dihapus).' });
  const x = h.sesi.titik.splice(h.indeks, 1)[0];
  h.berkas.setContent(JSON.stringify(h.sesi, null, 2));
  let fotoPindah = false;
  if (x.foto) {
    const folderFoto = subfolder(induk, 'foto');
    const f = folderFoto.getFilesByName(x.foto);
    if (f.hasNext()) {
      f.next().moveTo(subfolder(induk, 'sampah'));
      fotoPindah = true;
    }
  }
  hapusCache();
  catatLog(adm.user, 'hapus', id, JSON.stringify(x));
  return jawab({ ok: true, id: id, dihapus: true, fotoPindah: fotoPindah });
}

// Jalankan SEKALI dari editor: membuat tab "Admin" dengan satu admin awal.
// Setelah itu ganti sandi langsung di Sheet (ketik sandi baru di kolom B).
function siapkanAdmin() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName('Admin');
  if (sh) { Logger.log('Tab Admin sudah ada, tidak diubah.'); return; }
  sh = ss.insertSheet('Admin');
  sh.getRange('B:B').setNumberFormat('@');
  sh.getRange(1, 1, 1, 4).setValues([['user', 'sandi', 'aktif', 'peran']]);
  sh.getRange(2, 1, 1, 4).setValues([['admin', '123456', 'ya', 'admin']]);
  Logger.log('Tab Admin dibuat. User: admin, sandi awal: 123456. GANTI SEGERA.');
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
  CacheService.getScriptCache().get('x');
  Logger.log('Izin OK');
}
