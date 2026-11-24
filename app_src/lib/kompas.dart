import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Arah kamera belakang (0-360 derajat dari utara), dihitung dari akselerometer
/// dan magnetometer. Arah dihitung untuk sumbu kamera, jadi tetap benar saat HP
/// dipegang tegak untuk memotret.
class Kompas {
  List<double>? _a, _m;
  double? arah;

  /// Posisi fisik HP (potret/lanskap) dari akselerometer. Layar aplikasi terkunci
  /// potret, jadi posisi ini dipakai untuk memberi tahu kamera arah foto.
  DeviceOrientation orientasi = DeviceOrientation.portraitUp;
  bool get lanskap =>
      orientasi == DeviceOrientation.landscapeLeft || orientasi == DeviceOrientation.landscapeRight;
  StreamSubscription<dynamic>? _sa, _sm;

  void mulai() {
    _sa = accelerometerEventStream().listen((e) {
      _a = _haluskan(_a, [e.x, e.y, e.z]);
      _hitungOrientasi();
      _hitung();
    }, onError: (_) {});
    _sm = magnetometerEventStream().listen((e) {
      _m = _haluskan(_m, [e.x, e.y, e.z]);
      _hitung();
    }, onError: (_) {});
  }

  void henti() {
    _sa?.cancel();
    _sm?.cancel();
  }

  List<double> _haluskan(List<double>? lama, List<double> baru) => lama == null
      ? baru
      : [for (var i = 0; i < 3; i++) lama[i] + 0.12 * (baru[i] - lama[i])];

  /// Selisih 3 m/s2 sebagai batas agar tidak bolak-balik saat HP miring ~45 derajat.
  /// Saat HP hampir rata, orientasi terakhir dipertahankan.
  void _hitungOrientasi() {
    final a = _a;
    if (a == null) return;
    final x = a[0], y = a[1];
    if (x.abs() > y.abs() + 3) {
      orientasi = x > 0 ? DeviceOrientation.landscapeLeft : DeviceOrientation.landscapeRight;
    } else if (y.abs() > x.abs() + 3) {
      orientasi = y > 0 ? DeviceOrientation.portraitUp : DeviceOrientation.portraitDown;
    }
  }

  void _hitung() {
    final a = _a, m = _m;
    if (a == null || m == null) return;
    var ax = a[0], ay = a[1], az = a[2];
    final ex = m[0], ey = m[1], ez = m[2];
    var hx = ey * az - ez * ay;
    var hy = ez * ax - ex * az;
    var hz = ex * ay - ey * ax;
    final nh = sqrt(hx * hx + hy * hy + hz * hz);
    final na = sqrt(ax * ax + ay * ay + az * az);
    if (nh < 0.1 || na < 0.1) return;
    hx /= nh; hy /= nh; hz /= nh;
    ax /= na; ay /= na; az /= na;
    final my = az * hx - ax * hz;
    final mz = ax * hy - ay * hx;
    final mendatar = sqrt(hz * hz + mz * mz);
    // Kamera menghadap -Z perangkat. Jika HP hampir rata, pakai arah atas HP.
    final rad = mendatar > 0.35 ? atan2(-hz, -mz) : atan2(hy, my);
    arah = (rad * 180 / pi + 360) % 360;
  }
}
