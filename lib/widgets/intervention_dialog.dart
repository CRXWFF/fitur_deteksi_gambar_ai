import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/content_analysis_service.dart';

/// Widget: Dialog intervensi full-screen saat detect konten berbahaya
/// Menampilkan peringatan dengan level: LOW (kuning), MEDIUM (orange), HIGH (merah)
///
/// LOW: User bisa pilih "Abaikan" atau "Tutup Aplikasi"
/// MEDIUM/HIGH: User harus klik "Tutup Aplikasi" (tidak bisa abaikan)
class InterventionDialog extends StatelessWidget {
  final ContentLevel level;
  final String appName;
  final Uint8List imageBytes;
  final VoidCallback onDismiss;
  final VoidCallback onCloseApp;

  const InterventionDialog({
    Key? key,
    required this.level,
    required this.appName,
    required this.imageBytes,
    required this.onDismiss,
    required this.onCloseApp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Dapatkan warna, label, title, dan deskripsi berdasarkan level
    Color themeColor = ContentAnalysisService.getColorForLevel(level);
    String levelLabel = ContentAnalysisService.getLabelForLevel(level);
    String title = ContentAnalysisService.getTitleForLevel(level);
    String description = ContentAnalysisService.getDescriptionForLevel(level);

    // LOW: tampilkan 2 tombol (Abaikan + Tutup)
    // MEDIUM/HIGH: tampilkan 1 tombol (Tutup saja)
    bool canDismiss = (level == ContentLevel.low);

    return WillPopScope(
      // Disable tombol back HP
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.95),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon peringatan dengan animasi pulse
                _buildWarningIcon(themeColor),

                SizedBox(height: 32),

                // Badge level dengan warna sesuai tingkat bahaya
                _buildLevelBadge(levelLabel, themeColor),

                SizedBox(height: 20),

                // Title peringatan
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12),

                // Deskripsi
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 32),

                // Preview gambar dengan blur & border warna
                _buildImagePreview(imageBytes, themeColor),

                SizedBox(height: 12),

                // Info nama aplikasi
                _buildAppInfo(appName),

                SizedBox(height: 40),

                // Tombol aksi
                if (canDismiss)
                  _buildTwoButtons(themeColor)
                else
                  _buildSingleButton(themeColor),

                SizedBox(height: 16),

                // Footer info
                _buildFooterInfo(canDismiss),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Widget: Icon peringatan dengan efek glowing
  Widget _buildWarningIcon(Color color) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        Icons.warning_rounded,
        size: 80,
        color: color,
      ),
    );
  }

  /// Widget: Badge level (LOW/MEDIUM/HIGH)
  Widget _buildLevelBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 3,
        ),
      ),
    );
  }

  /// Widget: Preview gambar dengan blur dan border
  Widget _buildImagePreview(Uint8List bytes, Color borderColor) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.4),
            BlendMode.darken,
          ),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  /// Widget: Info nama aplikasi
  Widget _buildAppInfo(String name) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apps, color: Colors.white60, size: 18),
          SizedBox(width: 8),
          Text(
            'Aplikasi: $name',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget: 2 tombol (untuk LOW)
  Widget _buildTwoButtons(Color themeColor) {
    return Row(
      children: [
        // Tombol Abaikan
        Expanded(
          child: OutlinedButton(
            onPressed: onDismiss,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white70, width: 2),
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Abaikan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(width: 16),
        // Tombol Tutup Aplikasi
        Expanded(
          child: ElevatedButton(
            onPressed: onCloseApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
            ),
            child: Text(
              'Tutup Aplikasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Widget: 1 tombol (untuk MEDIUM/HIGH)
  Widget _buildSingleButton(Color themeColor) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onCloseApp,
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor,
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
        child: Text(
          'Tutup Aplikasi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Widget: Footer info
  Widget _buildFooterInfo(bool canDismiss) {
    return Text(
      canDismiss
          ? 'Anda dapat memilih untuk mengabaikan atau menutup aplikasi'
          : 'Aplikasi akan ditutup untuk keamanan Anda',
      style: TextStyle(
        fontSize: 12,
        color: Colors.white38,
        fontStyle: FontStyle.italic,
      ),
      textAlign: TextAlign.center,
    );
  }
}
