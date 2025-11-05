package com.example.fitur_deteksi_gambar_ai

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

/**
 * ForceCloseAccessibilityService - Service untuk force close aplikasi lain
 * 
 * FUNGSI:
 * - Mendengarkan event dari sistem Android
 * - Menerima perintah dari Flutter untuk force close app
 * - Menggunakan `am force-stop` command untuk tutup aplikasi
 * 
 * PERMISSION:
 * - User harus aktifkan manual di Settings > Accessibility
 */
class ForceCloseAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ForceCloseService"
        
        // Instance service untuk akses dari MainActivity
        private var instance: ForceCloseAccessibilityService? = null
        
        fun getInstance(): ForceCloseAccessibilityService? = instance
        
        fun isServiceEnabled(): Boolean = instance != null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "✅ Accessibility Service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Tidak perlu handle event untuk force close
        // Hanya perlu service aktif untuk execute command
    }

    override fun onInterrupt() {
        Log.d(TAG, "⚠️ Service interrupted")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        Log.d(TAG, "🛑 Service unbind")
        return super.onUnbind(intent)
    }

    /**
     * Fungsi: Force close aplikasi dengan package name
     * Method: Menggunakan Runtime.exec("am force-stop packageName")
     * 
     * @param packageName Package name aplikasi target (contoh: "com.zhiliaoapp.musically")
     * @return true jika berhasil, false jika gagal
     */
    fun forceCloseApp(packageName: String): Boolean {
        return try {
            Log.d(TAG, "🚫 Attempting to force close: $packageName")
            
            // Execute command: am force-stop <packageName>
            val process = Runtime.getRuntime().exec(arrayOf("am", "force-stop", packageName))
            
            // Tunggu proses selesai (max 2 detik)
            val exitCode = process.waitFor()
            
            if (exitCode == 0) {
                Log.d(TAG, "✅ Successfully force closed: $packageName")
                true
            } else {
                Log.w(TAG, "⚠️ Force close failed with exit code: $exitCode")
                false
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error force closing app: ${e.message}")
            e.printStackTrace()
            false
        }
    }
}
