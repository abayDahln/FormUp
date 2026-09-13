/// Implementasi no-op untuk platform tanpa dukungan exam desktop
/// (mobile + web): semua panggilan aman dan mengembalikan kegagalan ringan.
class DesktopGuardState {
  final bool fullscreen;

  const DesktopGuardState({this.fullscreen = false});

  bool get ok => fullscreen;

  List<String> get failedLayers {
    final out = <String>[];
    if (!fullscreen) out.add('layar-penuh');
    return out;
  }
}

class DesktopExamGuardImpl {
  static Future<DesktopGuardState> enterExamWindow() async =>
      const DesktopGuardState();

  static Future<void> exitExamWindow() async {}

  static Future<void> reassertAffinity() async {}
}
