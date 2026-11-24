import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Arah kamera belakang (0-360 derajat dari utara), dihitung dari akselerometer
/// dan magnetometer. Arah dihitung untuk sumbu kamera, jadi tetap benar saat HP
/// dipegang tegak untuk memotret.
class Kompas {
  List<double>? _a, _m;
  double? arah;
  StreamSubscription<dynamic>? _sa, _sm;

  void mulai() {
    _sa = accelerometerEventStream().listen((e) {
      _a = _haluskan(_a, [e.x, e.y, e.z]);
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
