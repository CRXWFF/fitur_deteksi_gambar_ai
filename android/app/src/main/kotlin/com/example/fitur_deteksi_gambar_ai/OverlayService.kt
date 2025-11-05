package com.example.fitur_deteksi_gambar_ai

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import android.util.Log

/**
 * OVERLAY SERVICE - Tampilkan popup REALTIME di atas aplikasi lain (TikTok, Instagram, dll)
 * 
 * FLOW:
 * 1. Flutter detect konten berbahaya
 * 2. Flutter kirim intent ke OverlayService dengan data (level, app_name, image_bytes)
 * 3. OverlayService buat overlay window di atas aplikasi yang sedang dibuka
 * 4. User pilih aksi (Abaikan/Tutup Aplikasi)
 * 5. OverlayService broadcast hasil ke Flutter
 * 6. OverlayService hapus overlay
 */
class OverlayService : Service() {
    
    companion object {
        private const val TAG = "OverlayService"
        const val ACTION_SHOW_OVERLAY = "com.example.fitur_deteksi_gambar_ai.SHOW_OVERLAY"
        const val ACTION_HIDE_OVERLAY = "com.example.fitur_deteksi_gambar_ai.HIDE_OVERLAY"
        
        // Broadcast actions untuk komunikasi dengan Flutter
        const val BROADCAST_USER_DISMISSED = "com.example.fitur_deteksi_gambar_ai.USER_DISMISSED"
        const val BROADCAST_USER_CLOSE_APP = "com.example.fitur_deteksi_gambar_ai.USER_CLOSE_APP"
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: android.view.View? = null
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_OVERLAY -> {
                val level = intent.getStringExtra("level") ?: "LOW"
                val appName = intent.getStringExtra("app_name") ?: "Unknown"
                val imageBytes = intent.getByteArrayExtra("image_bytes")
                
                Log.d(TAG, "📢 Showing overlay: level=$level, app=$appName")
                showOverlay(level, appName, imageBytes)
            }
            ACTION_HIDE_OVERLAY -> {
                Log.d(TAG, "🔽 Hiding overlay")
                hideOverlay()
            }
        }
        
        return START_NOT_STICKY
    }
    
    /**
     * Tampilkan overlay window di atas aplikasi lain
     */
    private fun showOverlay(level: String, appName: String, imageBytes: ByteArray?) {
        try {
            // Jika sudah ada overlay, hapus dulu
            hideOverlay()
            
            windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            
            // Inflate layout overlay (kita akan buat layout sederhana)
            overlayView = createOverlayView(level, appName, imageBytes)
            
            // Setup WindowManager.LayoutParams untuk overlay
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }
            
            // Tampilkan overlay
            windowManager?.addView(overlayView, params)
            
            Log.d(TAG, "✅ Overlay shown successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing overlay: ${e.message}", e)
        }
    }
    
    /**
     * Buat view untuk overlay (native Android layout)
     */
    private fun createOverlayView(level: String, appName: String, imageBytes: ByteArray?): android.view.View {
        // Untuk sementara, kita buat layout programmatically
        // Nanti bisa diganti dengan inflate dari XML jika diperlukan
        
        val layout = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(android.graphics.Color.parseColor("#CC000000")) // Semi-transparent black
            setPadding(40, 40, 40, 40)
            gravity = Gravity.CENTER
        }
        
        // Icon warning
        val icon = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_dialog_alert)
            layoutParams = android.widget.LinearLayout.LayoutParams(200, 200).apply {
                gravity = Gravity.CENTER
                bottomMargin = 20
            }
        }
        layout.addView(icon)
        
        // Title
        val title = TextView(this).apply {
            text = "⚠️ KONTEN BERBAHAYA TERDETEKSI"
            textSize = 20f
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 20
            }
        }
        layout.addView(title)
        
        // Level badge
        val levelText = TextView(this).apply {
            text = "Level: $level"
            textSize = 16f
            setTextColor(android.graphics.Color.WHITE)
            val bgColor = when (level) {
                "LOW" -> android.graphics.Color.parseColor("#FFC107")
                "MEDIUM" -> android.graphics.Color.parseColor("#FF9800")
                "HIGH" -> android.graphics.Color.parseColor("#F44336")
                else -> android.graphics.Color.GRAY
            }
            setBackgroundColor(bgColor)
            setPadding(40, 20, 40, 20)
            gravity = Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 20
            }
        }
        layout.addView(levelText)
        
        // App name
        val appText = TextView(this).apply {
            text = "Aplikasi: $appName"
            textSize = 14f
            setTextColor(android.graphics.Color.WHITE)
            gravity = Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 40
            }
        }
        layout.addView(appText)
        
        // Tombol Abaikan (hanya untuk LOW)
        if (level == "LOW") {
            val btnDismiss = Button(this).apply {
                text = "Abaikan"
                textSize = 16f
                setBackgroundColor(android.graphics.Color.parseColor("#9E9E9E"))
                setTextColor(android.graphics.Color.WHITE)
                layoutParams = android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = 20
                }
                setOnClickListener {
                    Log.d(TAG, "ℹ️ User dismissed warning")
                    
                    // Broadcast ke Flutter
                    sendBroadcast(Intent(BROADCAST_USER_DISMISSED))
                    
                    // Hapus overlay
                    hideOverlay()
                    stopSelf()
                }
            }
            layout.addView(btnDismiss)
        }
        
        // Tombol Tutup Aplikasi
        val btnCloseApp = Button(this).apply {
            text = "Tutup Aplikasi"
            textSize = 16f
            setBackgroundColor(android.graphics.Color.parseColor("#F44336"))
            setTextColor(android.graphics.Color.WHITE)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setOnClickListener {
                Log.d(TAG, "🚫 User chose to close app: $appName")
                
                // Broadcast ke Flutter dengan data app_name
                sendBroadcast(Intent(BROADCAST_USER_CLOSE_APP).apply {
                    putExtra("app_name", appName)
                })
                
                // Hapus overlay
                hideOverlay()
                stopSelf()
            }
        }
        layout.addView(btnCloseApp)
        
        return layout
    }
    
    /**
     * Hapus overlay window
     */
    private fun hideOverlay() {
        try {
            overlayView?.let {
                windowManager?.removeView(it)
                overlayView = null
            }
            windowManager = null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error hiding overlay: ${e.message}", e)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        hideOverlay()
        Log.d(TAG, "🛑 OverlayService destroyed")
    }
}
