import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller zoom form: 0.8 - 1.6, step 0.1, persist SharedPreferences.
class FormZoomController extends ValueNotifier<double> {
  static const double minZoom = 0.8;
  static const double maxZoom = 1.6;
  static const double step = 0.1;
  static const String prefsKey = 'form_zoom_scale';

  FormZoomController() : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getDouble(prefsKey);
      if (v != null) value = v.clamp(minZoom, maxZoom);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(prefsKey, value);
    } catch (_) {}
  }

  bool get canZoomIn => value < maxZoom - 0.001;
  bool get canZoomOut => value > minZoom + 0.001;

  void zoomIn() {
    if (!canZoomIn) return;
    value = (value + step).clamp(minZoom, maxZoom);
    _save();
  }

  void zoomOut() {
    if (!canZoomOut) return;
    value = (value - step).clamp(minZoom, maxZoom);
    _save();
  }

  void reset() {
    value = 1.0;
    _save();
  }

  double scaled(double base, {double min = 10, double max = 48}) =>
      (base * value).clamp(min, max);

  String get label => '${(value * 100).round()}%';
}

/// Singleton global agar bisa dipakai di banyak screen tanpa Provider.
final formZoom = FormZoomController();
