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
    
    // Flag untuk track apakah capture sudah ready
    private var isCaptureReady = false
    
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
                        Log.d("MainActivity", "🎬 startCapture called")
                        pendingCaptureResult = result
                        isCaptureReady = false // Reset flag
                        requestMediaProjectionPermission()
                    }
                    
                    // Capture 1 frame dari screen
                    "captureFrame" -> {
                        Log.d("MainActivity", "📸 captureFrame called")
                        
                        // Check flag dulu
                        if (!isCaptureReady) {
                            Log.w("MainActivity", "⚠️ Capture not ready yet, returning null")
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        
                        try {
                            val imageBytes = screenCaptureHelper.captureFrame()
                            if (imageBytes != null) {
                                val sizeKB = imageBytes.size / 1024.0
                                Log.d("MainActivity", "✅ Captured ${String.format("%.2f", sizeKB)} KB")
                                result.success(imageBytes)
                            } else {
                                Log.w("MainActivity", "⚠️ captureFrame returned null")
                                result.success(null)
                            }
                        } catch (e: Exception) {
                            Log.e("MainActivity", "❌ Error: ${e.message}")
                            e.printStackTrace()
                            result.error("CAPTURE_ERROR", e.message, null)
                        }
                    }
                    
                    // Stop capture dan cleanup
                    "stopCapture" -> {
                        Log.d("MainActivity", "⏹️ stopCapture called")
                        
                        screenCaptureHelper.stopCapture()
                        isCaptureReady = false
                        
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
            Log.d("MainActivity", "📥 onActivityResult: code=$requestCode, result=$resultCode")
            
            if (resultCode == Activity.RESULT_OK && data != null) {
                Log.d("MainActivity", "✅ Permission GRANTED!")
                
                try {
                    val mediaProjection = projectionManager.getMediaProjection(Activity.RESULT_OK, data)
                    
                    if (mediaProjection != null) {
                        Log.d("MainActivity", "✅ MediaProjection created")
                        
                        // Setup capture
                        screenCaptureHelper.startCapture(mediaProjection)
                        Log.d("MainActivity", "✅ startCapture() completed")
                        
                        // WARM-UP: Wait 1.2 second lalu dummy capture
                        Handler(Looper.getMainLooper()).postDelayed({
                            Log.d("MainActivity", "🔥 Warming up VirtualDisplay...")
                            
                            try {
                                // Dummy capture untuk force render first frame
                                val dummyImage = screenCaptureHelper.captureFrame()
                                
                                if (dummyImage != null) {
                                    val sizeKB = dummyImage.size / 1024.0
                                    Log.d("MainActivity", "✅ Warm-up SUCCESS! ${String.format("%.2f", sizeKB)} KB")
                                    
                                    // SET FLAG READY!
                                    isCaptureReady = true
                                    Log.d("MainActivity", "✅ isCaptureReady = TRUE")
                                    
                                } else {
                                    Log.w("MainActivity", "⚠️ Warm-up returned null")
                                    
                                    // Retry 1x setelah 500ms
                                    Handler(Looper.getMainLooper()).postDelayed({
                                        Log.d("MainActivity", "🔄 Retry warm-up...")
                                        val retryImage = screenCaptureHelper.captureFrame()
                                        
                                        if (retryImage != null) {
                                            Log.d("MainActivity", "✅ Retry SUCCESS!")
                                            isCaptureReady = true
                                        } else {
                                            Log.e("MainActivity", "❌ Retry failed, setting ready anyway")
                                            isCaptureReady = true // Set true anyway
                                        }
                                        
                                    }, 500)
                                }
                                
                                // Notify Flutter
                                pendingCaptureResult?.success(true)
                                pendingCaptureResult = null
                                
                            } catch (e: Exception) {
                                Log.e("MainActivity", "❌ Warm-up error: ${e.message}")
                                e.printStackTrace()
                                
                                // Set ready anyway
                                isCaptureReady = true
                                
                                pendingCaptureResult?.success(true)
                                pendingCaptureResult = null
                            }
                            
                        }, 1200) // Wait 1.2 seconds
                        
                    } else {
                        Log.e("MainActivity", "❌ MediaProjection is null!")
                        pendingCaptureResult?.success(false)
                        pendingCaptureResult = null
                    }
                    
                } catch (e: Exception) {
                    Log.e("MainActivity", "❌ Error in onActivityResult: ${e.message}")
                    e.printStackTrace()
                    pendingCaptureResult?.success(false)
                    pendingCaptureResult = null
                }
                
            } else {
                Log.w("MainActivity", "❌ Permission DENIED! result=$resultCode")
                
                // Stop service
                val serviceIntent = Intent(this, ScreenCaptureService::class.java)
                stopService(serviceIntent)
                
                pendingCaptureResult?.success(false)
                pendingCaptureResult = null
            }
        }
    }
}
