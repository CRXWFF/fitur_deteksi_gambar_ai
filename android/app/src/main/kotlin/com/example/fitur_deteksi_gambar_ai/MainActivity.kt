package com.example.fitur_deteksi_gambar_ai

import android.app.Activity
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity - Bridge antara Flutter dan Native Android
 * 
 * FUNGSI:
 * 1. Handle method calls dari Flutter (via MethodChannel)
 * 2. Request MediaProjection permission
 * 3. Capture screenshot full screen
 * 4. Return data ke Flutter
 */
class MainActivity : FlutterActivity() {
    
    // Channel untuk deteksi aplikasi
    private val APP_DETECTION_CHANNEL = "com.reflvy.app/app_detection"
    
    // Channel untuk screen capture
    private val SCREEN_CAPTURE_CHANNEL = "com.reflvy.app/screen_capture"
    
    // Request code untuk MediaProjection permission
    private val REQUEST_CODE_SCREEN_CAPTURE = 1000
    
    // Helper classes
    private lateinit var appDetectionHelper: AppDetectionHelper
    private lateinit var screenCaptureHelper: ScreenCaptureHelper
    
    // MediaProjection manager
    private lateinit var projectionManager: MediaProjectionManager
    
    // Pending result untuk async permission request
    private var pendingCaptureResult: MethodChannel.Result? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d("MainActivity", "🚀 Configuring Flutter engine...")
        
        // Initialize helpers
        appDetectionHelper = AppDetectionHelper(this)
        screenCaptureHelper = ScreenCaptureHelper(this)
        projectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        
        // ====== CHANNEL 1: APP DETECTION ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_DETECTION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Cek apakah punya Usage Stats permission
                    "hasPermission" -> {
                        val hasPermission = appDetectionHelper.hasUsageStatsPermission()
                        result.success(hasPermission)
                    }
                    
                    // Buka Settings untuk aktifkan Usage Stats
                    "requestPermission" -> {
                        appDetectionHelper.openUsageStatsSettings()
                        result.success(null)
                    }
                    
                    // Get nama app yang sedang dibuka
                    "getCurrentApp" -> {
                        val appName = appDetectionHelper.getCurrentAppName()
                        result.success(appName)
                    }
                    
                    // Get package name app (untuk debugging)
                    "getCurrentPackage" -> {
                        val packageName = appDetectionHelper.getCurrentForegroundApp()
                        result.success(packageName)
                    }
                    
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        // ====== CHANNEL 2: SCREEN CAPTURE ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CAPTURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Request permission dan start capture
                    "startCapture" -> {
                        pendingCaptureResult = result
                        requestMediaProjectionPermission()
                    }
                    
                    // Capture 1 frame dari screen
                    "captureFrame" -> {
                        val imageBytes = screenCaptureHelper.captureFrame()
                        if (imageBytes != null) {
                            result.success(imageBytes)
                        } else {
                            result.error("CAPTURE_ERROR", "Failed to capture frame", null)
                        }
                    }

                    // Cek apakah capture sudah siap (VirtualDisplay & ImageReader OK)
                    "isReady" -> {
                        val ready = screenCaptureHelper.isReady()
                        result.success(ready)
                    }
                    
                    // Stop capture dan cleanup
                    "stopCapture" -> {
                        screenCaptureHelper.stopCapture()
                        
                        // Stop foreground service
                        val serviceIntent = Intent(this, ScreenCaptureService::class.java)
                        stopService(serviceIntent)
                        Log.d("MainActivity", "⏹️ Foreground service stopped")
                        
                        result.success(null)
                    }
                    
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        Log.d("MainActivity", "✅ Flutter engine configured!")
    }
    
    /**
     * Request MediaProjection permission dari user
     * Akan muncul system dialog "Start capturing screen?"
     */
    private fun requestMediaProjectionPermission() {
        Log.d("MainActivity", "🔐 Requesting MediaProjection permission...")
        
        try {
            // STEP 1: Start foreground service DULU (wajib di Android 14+)
            val serviceIntent = Intent(this, ScreenCaptureService::class.java)
            startForegroundService(serviceIntent)
            Log.d("MainActivity", "✅ Foreground service starting...")
            
            // STEP 2: Tunggu service start (500ms)
            Handler(Looper.getMainLooper()).postDelayed({
                // STEP 3: Launch permission dialog
                val permissionIntent = projectionManager.createScreenCaptureIntent()
                
                Log.d("MainActivity", "🚀 Launching screen capture permission intent...")
                startActivityForResult(permissionIntent, REQUEST_CODE_SCREEN_CAPTURE)
            }, 500)
            
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ Error launching permission: ${e.message}")
            e.printStackTrace()
            pendingCaptureResult?.success(false)
            pendingCaptureResult = null
        }
    }
    
    /**
     * Callback saat user approve/deny permission
     */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_CODE_SCREEN_CAPTURE) {
            Log.d("MainActivity", "📥 Activity result: requestCode=$requestCode, resultCode=$resultCode")
            
            if (resultCode == Activity.RESULT_OK && data != null) {
                Log.d("MainActivity", "✅ MediaProjection permission granted by user!")
                
                try {
                    // Get MediaProjection dari result
                    val mediaProjection = projectionManager.getMediaProjection(Activity.RESULT_OK, data)
                    
                    if (mediaProjection != null) {
                        Log.d("MainActivity", "✅ MediaProjection object created successfully!")
                        
                        // Setup capture helper
                        screenCaptureHelper.startCapture(mediaProjection)
                        
                        // Notify Flutter: permission granted & ready
                        pendingCaptureResult?.success(true)
                        Log.d("MainActivity", "✅ Screen capture started successfully!")
                    } else {
                        Log.e("MainActivity", "❌ MediaProjection is null!")
                        pendingCaptureResult?.success(false)
                    }
                    
                } catch (e: Exception) {
                    Log.e("MainActivity", "❌ Error starting capture: ${e.message}")
                    e.printStackTrace()
                    pendingCaptureResult?.success(false)
                }
                
            } else {
                Log.w("MainActivity", "❌ MediaProjection permission denied by user! resultCode=$resultCode")
                
                // Stop service karena permission ditolak
                val serviceIntent = Intent(this, ScreenCaptureService::class.java)
                stopService(serviceIntent)
                
                pendingCaptureResult?.success(false)
            }
            
            pendingCaptureResult = null
        }
    }
}
