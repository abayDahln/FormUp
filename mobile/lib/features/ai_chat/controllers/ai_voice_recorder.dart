import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/widgets/responsive.dart';

/// Perekam suara untuk fitur AI: rekam WAV 16 kHz mono, lalu transkrip lewat
/// Gemini. Satu implementasi untuk AI Chat dan AI Form Agent agar perilakunya
/// sama (izin mikrofon, auto-stop 60 detik, bersih-bersih file temporer).
///
/// Pemanggil bertanggung jawab menampilkan pesan ([onMessage]), membuka dialog
/// API key ([onNeedApiKey]), menyisipkan hasil transkrip ([onText]), dan
/// memicu rebuild UI ([onStateChanged]).
class AiVoiceRecorder {
  AudioRecorder? _recorder;
  Timer? _timer;
  String? _path;
  bool _isRecording = false;
  bool _isTranscribing = false;

  bool get isRecording => _isRecording;
  bool get isTranscribing => _isTranscribing;

  /// Mulai merekam, atau berhenti + transkrip bila sedang merekam.
  Future<void> toggle({
    required void Function(String text) onText,
    required void Function(String message, {bool isError}) onMessage,
    required VoidCallback onNeedApiKey,
    required VoidCallback onStateChanged,
  }) async {
    if (_isTranscribing) return;
    if (_isRecording) {
      await _stopAndTranscribe(
        onText: onText,
        onMessage: onMessage,
        onStateChanged: onStateChanged,
      );
      return;
    }
    if (!GeminiService.hasKey) {
      onMessage('API Key belum diatur', isError: true);
      onNeedApiKey();
      return;
    }
    try {
      if (!isDesktopPlatform) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          onMessage('Izin mikrofon ditolak', isError: true);
          return;
        }
      }
      _recorder ??= AudioRecorder();
      bool hasPerm = true;
      try {
        hasPerm = await _recorder!.hasPermission();
      } on MissingPluginException {
        hasPerm = true; // Windows: hasPermission tidak diimplementasikan
      } catch (_) {
        hasPerm = true;
      }
      if (!hasPerm) {
        onMessage('Mikrofon tidak tersedia', isError: true);
        return;
      }
      final tempDir = await Directory.systemTemp.createTemp('voice_');
      _path = '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: _path!,
      );
      _isRecording = true;
      onStateChanged();
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 60), () {
        if (_isRecording) {
          _stopAndTranscribe(
            onText: onText,
            onMessage: onMessage,
            onStateChanged: onStateChanged,
          );
        }
      });
    } on MissingPluginException catch (_) {
      _isRecording = false;
      onStateChanged();
      onMessage('Plugin voice belum terpasang di Windows.', isError: true);
    } catch (e) {
      _isRecording = false;
      onStateChanged();
      onMessage('Gagal merekam: $e', isError: true);
    }
  }

  Future<void> _stopAndTranscribe({
    required void Function(String text) onText,
    required void Function(String message, {bool isError}) onMessage,
    required VoidCallback onStateChanged,
  }) async {
    if (!_isRecording) return;
    _timer?.cancel();
    _isRecording = false;
    _isTranscribing = true;
    onStateChanged();
    try {
      final path = await _recorder?.stop();
      final effectivePath = path ?? _path;
      _path = null;
      if (effectivePath == null || !File(effectivePath).existsSync()) {
        throw Exception('File rekaman tidak ditemukan');
      }
      final bytes = await File(effectivePath).readAsBytes();
      try {
        await File(effectivePath).delete();
      } catch (_) {}
      try {
        final dir = Directory(File(effectivePath).parent.path);
        if (dir.path.contains('voice_')) await dir.delete(recursive: true);
      } catch (_) {}
      if (bytes.isEmpty) throw Exception('Rekaman kosong');
      final text = await GeminiService.transcribeAudio(bytes, mime: 'audio/wav');
      if (text.trim().isEmpty) {
        onMessage('Transkripsi kosong. Coba bicara lebih jelas.',
            isError: true);
        return;
      }
      onText(text.trim());
    } catch (e) {
      onMessage(GeminiService.friendlyMessage(e), isError: true);
    } finally {
      _isTranscribing = false;
      onStateChanged();
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _recorder?.dispose();
    _recorder = null;
  }
}
