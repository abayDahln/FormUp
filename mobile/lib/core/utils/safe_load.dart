/// Eksekusi [fn] dan tangkap error menjadi record `(data, error)`.
/// `error` null = sukses.
///
/// Dipakai batch load paralel (Beranda, Respon, Profil): tiap sumber data
/// ditangani sendiri agar satu request yang gagal-cepat tidak menghanguskan
/// data sumber lain dalam satu layar.
Future<(T?, Object?)> captureLoad<T>(Future<T> Function() fn) async {
  try {
    return (await fn(), null);
  } catch (e) {
    return (null, e);
  }
}
