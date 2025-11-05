package com.example.fitur_deteksi_gambar_ai

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
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
                // ✅ NO MORE image_bytes - fixed TransactionTooLargeException
                
                Log.d(TAG, "📢 Showing overlay: level=$level, app=$appName")
                showOverlay(level, appName)
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
    private fun showOverlay(level: String, appName: String) {
        try {
            // CRITICAL: Check overlay permission
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!Settings.canDrawOverlays(this)) {
                    Log.e(TAG, "❌ OVERLAY PERMISSION NOT GRANTED! Cannot display overlay.")
                    return
                } else {
                    Log.d(TAG, "✅ Overlay permission granted, proceeding...")
                }
            }
            
            // Jika sudah ada overlay, hapus dulu
            hideOverlay()
            
            windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            Log.d(TAG, "🪟 WindowManager obtained")
            
            // Inflate layout overlay
            overlayView = createOverlayView(level, appName)
            Log.d(TAG, "🎨 Overlay view created")
            
            // Setup WindowManager.LayoutParams untuk overlay
            val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            Log.d(TAG, "📱 Using window type: $windowType (SDK: ${Build.VERSION.SDK_INT})")
            
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                windowType,
                // ✅ FIXED: Remove FLAG_NOT_FOCUSABLE to allow button clicks
                // Use FLAG_NOT_TOUCH_MODAL to allow touches on overlay but pass through to background
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }
            
            Log.d(TAG, "🎯 Window flags: FLAG_NOT_TOUCH_MODAL | FLAG_LAYOUT_IN_SCREEN | FLAG_KEEP_SCREEN_ON")
            
            // Tampilkan overlay
            Log.d(TAG, "🎯 Adding view to WindowManager...")
            windowManager?.addView(overlayView, params)
            
            Log.d(TAG, "✅✅✅ OVERLAY DISPLAYED SUCCESSFULLY! Should be visible over other apps now! ✅✅✅")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing overlay: ${e.message}", e)
        }
    }
    
    /**
     * Buat view untuk overlay (native Android layout)
     */
    private fun createOverlayView(level: String, appName: String): android.view.View {
        // Inflate layout dari XML
        val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as android.view.LayoutInflater
        val view = inflater.inflate(R.layout.reflvy_overlay, null)
        
        Log.d(TAG, "📄 Layout inflated successfully")
        
        // Update dynamic content
        val tvTitle = view.findViewById<TextView>(R.id.tvTitle)
        val tvBadge = view.findViewById<TextView>(R.id.tvBadge)
        val tvDesc = view.findViewById<TextView>(R.id.tvDesc)
        val btnIgnore = view.findViewById<Button>(R.id.btnIgnore)
        val btnClose = view.findViewById<Button>(R.id.btnClose)
        
        // Set title
        tvTitle.text = "⚠️ KONTEN BERBAHAYA TERDETEKSI"
        
        // Set badge based on level
        tvBadge.text = level
        val badgeColor = when (level) {
            "LOW" -> android.graphics.Color.parseColor("#FFC107")
            "MEDIUM" -> android.graphics.Color.parseColor("#FF9800")
            "HIGH" -> android.graphics.Color.parseColor("#F44336")
            else -> android.graphics.Color.GRAY
        }
        tvBadge.setBackgroundColor(badgeColor)
        
        // Set description
        val description = when (level) {
            "LOW" -> "Terdeteksi konten berisiko rendah di $appName."
            "MEDIUM" -> "Terdeteksi konten berisiko sedang di $appName."
            "HIGH" -> "Terdeteksi konten berisiko tinggi di $appName!"
            else -> "Terdeteksi konten berbahaya di $appName."
        }
        tvDesc.text = description
        
        // Setup button click handlers
        btnIgnore.setOnClickListener {
            Log.d(TAG, "ℹ️ User clicked 'Abaikan' button")
            
            // Broadcast ke Flutter
            val dismissIntent = Intent(BROADCAST_USER_DISMISSED)
            sendBroadcast(dismissIntent)
            Log.d(TAG, "📤 Broadcast sent: $BROADCAST_USER_DISMISSED")
            
            // Hapus overlay IMMEDIATELY
            hideOverlay()
            
            // Stop service AFTER delay to ensure broadcast is received
            Handler(Looper.getMainLooper()).postDelayed({
                Log.d(TAG, "⏱️ Stopping service after broadcast delay...")
                stopSelf()
            }, 300) // 300ms delay
        }
        
        btnClose.setOnClickListener {
            Log.d(TAG, "🚫 User clicked 'Tutup Aplikasi' button for: $appName")
            
            // Broadcast ke Flutter dengan data app_name
            val closeIntent = Intent(BROADCAST_USER_CLOSE_APP).apply {
                putExtra("app_name", appName)
            }
            sendBroadcast(closeIntent)
            Log.d(TAG, "📤 Broadcast sent: $BROADCAST_USER_CLOSE_APP with app=$appName")
            
            // Hapus overlay IMMEDIATELY
            hideOverlay()
            
            // Minimize app: kirim user ke home screen
            try {
                val homeIntent = Intent(Intent.ACTION_MAIN)
                homeIntent.addCategory(Intent.CATEGORY_HOME)
                homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(homeIntent)
                Log.d(TAG, "🏠 User sent to home screen (minimize)")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to minimize app: ${e.message}")
            }
            
            // Stop service AFTER delay to ensure broadcast is received
            Handler(Looper.getMainLooper()).postDelayed({
                Log.d(TAG, "⏱️ Stopping service after broadcast delay...")
                stopSelf()
            }, 300) // 300ms delay
        }
        
        // Hide "Abaikan" button if level is not LOW
        if (level != "LOW") {
            btnIgnore.visibility = android.view.View.GONE
            Log.d(TAG, "🔒 'Abaikan' button hidden for level: $level")
        }
        
        return view
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
