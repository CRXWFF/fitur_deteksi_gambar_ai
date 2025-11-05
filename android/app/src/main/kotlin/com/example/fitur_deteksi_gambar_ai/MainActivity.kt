package com.example.fitur_deteksi_gambar_ai

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity - Bridge antara Flutter dan Native Android
 * 
 * FUNGSI:
 * 1. Handle method calls dari Flutter (via MethodChannel)
 * 2. Request MediaProjection permission
 * 3. Capture screenshot full screen
 * 4. Force close aplikasi lain (via Accessibility Service)
 * 5. Return data ke Flutter
 */
class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "MainActivity"
    }
    
    // Channel untuk deteksi aplikasi
    private val APP_DETECTION_CHANNEL = "com.reflvy.app/app_detection"
    
    // Channel untuk screen capture
    private val SCREEN_CAPTURE_CHANNEL = "com.reflvy.app/screen_capture"
    
    // Channel untuk force close aplikasi
    private val APP_KILLER_CHANNEL = "com.reflvy.app/app_killer"
    
    // Channel untuk overlay realtime
    private val OVERLAY_CHANNEL = "com.reflvy.app/overlay"
    private val OVERLAY_EVENT_CHANNEL = "com.reflvy.app/overlay_events"
    
    // Request code untuk MediaProjection permission
    private val REQUEST_CODE_SCREEN_CAPTURE = 1000
    
    // Event sink untuk broadcast overlay events
    private var overlayEventSink: EventChannel.EventSink? = null
    // If Flutter is not listening when a broadcast arrives, store it here so Dart can poll later
    private var pendingOverlayEvent: Map<String, String>? = null
    private var isOverlayReceiverRegistered: Boolean = false
    
    // BroadcastReceiver untuk overlay events
    private val overlayBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            Log.d(TAG, "📨📨📨 BroadcastReceiver.onReceive() called! action=${intent?.action}")

            when (intent?.action) {
                OverlayService.BROADCAST_USER_DISMISSED -> {
                    Log.d(TAG, "✅ Received BROADCAST_USER_DISMISSED")

                    val payload = mapOf("action" to "dismissed")

                    if (overlayEventSink != null) {
                        overlayEventSink?.success(payload)
                        Log.d(TAG, "📤 Event sent to Flutter: dismissed")
                    } else {
                        // Store pending event so Dart can poll when it resumes
                        pendingOverlayEvent = mapOf("action" to "dismissed")
                        Log.d(TAG, "📥 overlayEventSink null - pending event saved")
                    }
                }
                OverlayService.BROADCAST_USER_CLOSE_APP -> {
                    val appName = intent.getStringExtra("app_name") ?: "Unknown"
                    Log.d(TAG, "✅ Received BROADCAST_USER_CLOSE_APP for: $appName")

                    val payload = mapOf("action" to "close_app", "app_name" to appName)

                    if (overlayEventSink != null) {
                        overlayEventSink?.success(payload)
                        Log.d(TAG, "📤 Event sent to Flutter: close_app, app=$appName")
                    } else {
                        pendingOverlayEvent = payload
                        Log.d(TAG, "📥 overlayEventSink null - pending close_app event saved")
                    }
                }
                else -> {
                    Log.w(TAG, "⚠️ Unknown broadcast action received: ${intent?.action}")
                }
            }
        }
    }
    
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
        
        // Setup EventChannel untuk overlay events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    overlayEventSink = events
                    Log.d(TAG, "✅ Overlay EventChannel listening")

                    // If there was a pending event while Dart wasn't listening, forward it now
                    pendingOverlayEvent?.let { evt ->
                        Log.d(TAG, "📦 Flushing pending overlay event to Dart: $evt")
                        overlayEventSink?.success(evt)
                        pendingOverlayEvent = null
                    }
                }
                
                override fun onCancel(arguments: Any?) {
                    // Do NOT unregister receiver here - keep receiver active so we don't miss broadcasts
                    overlayEventSink = null
                    Log.d(TAG, "🔇 Overlay EventChannel cancelled (receiver kept registered)")
                }
            })

        // Register overlay broadcast receiver once globally (keep registered across Dart pause/resume)
        if (!isOverlayReceiverRegistered) {
            val filter = IntentFilter().apply {
                addAction(OverlayService.BROADCAST_USER_DISMISSED)
                addAction(OverlayService.BROADCAST_USER_CLOSE_APP)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(overlayBroadcastReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(overlayBroadcastReceiver, filter)
            }
            isOverlayReceiverRegistered = true
            Log.d(TAG, "� Overlay BroadcastReceiver registered globally")
        }
        
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
        
        // ====== CHANNEL 3: OVERLAY (REALTIME POPUP) ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Cek apakah SYSTEM_ALERT_WINDOW permission sudah aktif
                    "canDrawOverlays" -> {
                        val canDraw = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this)
                        } else {
                            true // Android < 6.0 tidak perlu permission
                        }
                        result.success(canDraw)
                    }
                    
                    // Buka pengaturan overlay
                    "openOverlaySettings" -> {
                        try {
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    android.net.Uri.parse("package:$packageName")
                                )
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(intent)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error opening overlay settings: ${e.message}")
                            result.error("ERROR", e.message, null)
                        }
                    }
                    
                    // Tampilkan overlay
                    "showOverlay" -> {
                        val level = call.argument<String>("level")
                        val appName = call.argument<String>("app_name")
                        val imageBytes = call.argument<ByteArray>("image_bytes")
                        
                        if (level == null || appName == null) {
                            result.error("INVALID_ARGUMENT", "level and app_name are required", null)
                            return@setMethodCallHandler
                        }
                        
                        Log.d(TAG, "📤 Starting OverlayService: level=$level, app=$appName")
                        
                        // Start OverlayService (NO MORE image_bytes - fixed TransactionTooLargeException)
                        val intent = Intent(this, OverlayService::class.java).apply {
                            action = OverlayService.ACTION_SHOW_OVERLAY
                            putExtra("level", level)
                            putExtra("app_name", appName)
                            // ✅ NO MORE image_bytes
                        }
                        
                        startService(intent)
                        result.success(null)
                    }
                    
                    // Sembunyikan overlay
                    "hideOverlay" -> {
                        val intent = Intent(this, OverlayService::class.java).apply {
                            action = OverlayService.ACTION_HIDE_OVERLAY
                        }
                        startService(intent)
                        result.success(null)
                    }
                    
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        
        // ====== CHANNEL 4: APP KILLER (FORCE CLOSE) ======
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_KILLER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Cek apakah Accessibility Service sudah aktif
                    "isAccessibilityEnabled" -> {
                        val isEnabled = ForceCloseAccessibilityService.isServiceEnabled()
                        Log.d("MainActivity", "Accessibility enabled: $isEnabled")
                        result.success(isEnabled)
                    }
                    
                    // Buka pengaturan Accessibility
                    "openAccessibilitySettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "Error opening accessibility settings: ${e.message}")
                            result.error("ERROR", e.message, null)
                        }
                    }
                    
                    // Force close aplikasi target
                    "forceCloseApp" -> {
                        val packageName = call.argument<String>("packageName")
                        
                        if (packageName == null) {
                            result.error("INVALID_ARGUMENT", "packageName is required", null)
                            return@setMethodCallHandler
                        }
                        
                        val service = ForceCloseAccessibilityService.getInstance()
                        
                        if (service == null) {
                            Log.w("MainActivity", "❌ Accessibility Service not running")
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        
                        val success = service.forceCloseApp(packageName)
                        result.success(success)
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
