import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Level bahaya konten yang terdeteksi
enum ContentLevel {
  safe, // Aman - tidak ada intervensi
  low, // Peringatan rendah - kuning
  medium, // Peringatan sedang - orange
  high // Peringatan tinggi - merah
}

/// Service untuk analisis konten gambar
/// Saat ini menggunakan DUMMY (random) untuk testing
/// Nanti bisa diganti dengan real AI API (Google Vision, AWS Rekognition, dll)
class ContentAnalysisService {
  final Random _random = Random();

  /// Fungsi: Analisis screenshot dan kembalikan level bahaya
  /// Input: Uint8List (gambar dalam bentuk bytes)
  /// Output: ContentLevel (safe, low, medium, high)
  ///
  /// Distribusi probabilitas DUMMY:
  /// - 60% SAFE (konten aman)
  /// - 20% LOW (peringatan rendah)
  /// - 15% MEDIUM (peringatan sedang)
  /// - 5% HIGH (peringatan tinggi)
  Future<ContentLevel> analyzeContent(Uint8List imageBytes) async {
    // Simulasi delay API call (300ms)
    await Future.delayed(Duration(milliseconds: 300));

    // Generate random number 0-99
    int randomValue = _random.nextInt(100);

    print('🎲 Hasil analisis random: $randomValue');

    // Tentukan level berdasarkan random value
    if (randomValue < 60) {
      return ContentLevel.safe; // 0-59: SAFE
    } else if (randomValue < 80) {
      return ContentLevel.low; // 60-79: LOW
    } else if (randomValue < 95) {
      return ContentLevel.medium; // 80-94: MEDIUM
    } else {
      return ContentLevel.high; // 95-99: HIGH
    }
  }

  /// Fungsi: Dapatkan warna berdasarkan level
  static Color getColorForLevel(ContentLevel level) {
    switch (level) {
      case ContentLevel.safe:
        return Colors.green.shade600;
      case ContentLevel.low:
        return Color(0xFFFFC107); // Kuning modern
      case ContentLevel.medium:
        return Color(0xFFFF9800); // Orange modern
      case ContentLevel.high:
        return Color(0xFFF44336); // Merah modern
    }
  }

  /// Fungsi: Dapatkan label text berdasarkan level
  static String getLabelForLevel(ContentLevel level) {
    switch (level) {
      case ContentLevel.safe:
        return 'AMAN';
      case ContentLevel.low:
        return 'LOW';
      case ContentLevel.medium:
        return 'MEDIUM';
      case ContentLevel.high:
        return 'HIGH';
    }
  }

  /// Fungsi: Dapatkan deskripsi berdasarkan level
  static String getDescriptionForLevel(ContentLevel level) {
    switch (level) {
      case ContentLevel.safe:
        return 'Konten aman untuk dilihat';
      case ContentLevel.low:
        return 'Terdeteksi konten berisiko rendah (Low NSFW).';
      case ContentLevel.medium:
        return 'Terdeteksi konten berisiko sedang (Medium NSFW).';
      case ContentLevel.high:
        return 'Terdeteksi konten berisiko tinggi (High NSFW).';
    }
  }

  /// Fungsi: Dapatkan title berdasarkan level
  static String getTitleForLevel(ContentLevel level) {
    switch (level) {
      case ContentLevel.safe:
        return 'Konten Aman';
      case ContentLevel.low:
        return 'Peringatan Konten Rendah';
      case ContentLevel.medium:
        return 'Peringatan Konten Sedang';
      case ContentLevel.high:
        return 'Peringatan Konten Tinggi';
    }
  }
}
