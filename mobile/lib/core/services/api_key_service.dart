import 'auth_service.dart';

/// Hasil redeem kode API key: label + key asli dari server.
class RedeemedApiKey {
  final String? label;
  final String apiKey;

  const RedeemedApiKey({this.label, required this.apiKey});
}

/// Klien redeem API key Gemini (POST /api-keys/redeem — wajib login).
class ApiKeyService {
  /// Tukar [code] menjadi API key. Lempar [ApiException] bila kode salah
  /// (pesan server Bahasa Indonesia, tampilkan via AuthService.errorMessage).
  static Future<RedeemedApiKey> redeemApiKey(String code) async {
    final json = await AuthService.post('/api-keys/redeem', {'code': code.trim()});
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final apiKey = (data['apiKey'] as String? ?? '').trim();
    if (apiKey.isEmpty) {
      throw const ApiException('Kode tidak valid.');
    }
    return RedeemedApiKey(
      label: (data['label'] as String?)?.trim(),
      apiKey: apiKey,
    );
  }
}
