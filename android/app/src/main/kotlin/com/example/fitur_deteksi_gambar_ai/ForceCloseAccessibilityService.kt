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
     * Force close aplikasi target dengan otomatisasi Accessibility:
     * - Buka halaman App Info aplikasi target
     * - Klik tombol "Paksa berhenti" / "Force stop"
     * - Klik tombol konfirmasi "OK" / "Force stop"
     * Catatan: Teks tombol dapat berbeda antar vendor/locale, cari beberapa variasi.
     */
    fun forceCloseApp(packageName: String): Boolean {
        Log.d(TAG, "🚫 Attempting to force close via Accessibility: $packageName")

        return try {
            // Buka halaman App Info
            val intent = android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)

            // Jalankan automasi klik di background thread
            Thread {
                // Polling maksimal ~6 detik (20x * 300ms)
                repeat(20) {
                    try {
                        Thread.sleep(300)
                    } catch (_: InterruptedException) {}

                    val root = rootInActiveWindow ?: return@repeat

                    // Cari tombol "Paksa berhenti" / "Force stop"
                    val stopNodes = mutableListOf<android.view.accessibility.AccessibilityNodeInfo>()
                    stopNodes += root.findAccessibilityNodeInfosByText("Paksa berhenti")
                    stopNodes += root.findAccessibilityNodeInfosByText("Force stop")
                    stopNodes += root.findAccessibilityNodeInfosByText("Paksa Berhenti")

                    if (stopNodes.isNotEmpty()) {
                        val stopBtn = stopNodes.first()
                        val clicked = stopBtn.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK)
                        Log.d(TAG, "🔘 Click Force Stop: $clicked")

                        // Tunggu dialog konfirmasi
                        try { Thread.sleep(250) } catch (_: InterruptedException) {}

                        val confirmRoot = rootInActiveWindow ?: return@repeat
                        val okNodes = mutableListOf<android.view.accessibility.AccessibilityNodeInfo>()
                        okNodes += confirmRoot.findAccessibilityNodeInfosByText("OK")
                        okNodes += confirmRoot.findAccessibilityNodeInfosByText("Oke")
                        okNodes += confirmRoot.findAccessibilityNodeInfosByText("Force stop")
                        okNodes += confirmRoot.findAccessibilityNodeInfosByText("Paksa berhenti")

                        if (okNodes.isNotEmpty()) {
                            val okBtn = okNodes.first()
                            val okClicked = okBtn.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK)
                            Log.d(TAG, "✅ Confirm Force Stop: $okClicked")
                        }

                        return@Thread
                    }
                }
                Log.w(TAG, "⚠️ Could not find Force Stop button. Vendor UI may differ.")
            }.start()

            true
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error force closing app: ${e.message}")
            e.printStackTrace()
            false
        }
    }
}
