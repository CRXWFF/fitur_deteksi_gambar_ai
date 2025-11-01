package com.example.fitur_deteksi_gambar_ai

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

/**
 * ScreenCaptureHelper - Aggressive capture mode
 * Langsung capture tanpa wait - jika belum ready return null
 */
class ScreenCaptureHelper(private val context: Context) {
    
    private val TAG = "ScreenCaptureHelper"
    
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    
    private var screenWidth: Int = 0
    private var screenHeight: Int = 0
    private var screenDensity: Int = 0

    /**
     * Cek apakah capture sudah siap (simple check tanpa wait)
     */
    fun isReady(): Boolean {
        val ready = imageReader != null && virtualDisplay != null
        Log.d(TAG, "🔍 isReady: imageReader=${imageReader != null}, virtualDisplay=${virtualDisplay != null} -> $ready")
        return ready
    }
    
    /**
     * Setup MediaProjection dan mulai capture
     * 
     * @param projection MediaProjection instance dari system
     */
    fun startCapture(projection: MediaProjection?) {
        if (projection == null) {
            Log.e(TAG, "❌ MediaProjection is null! Cannot start capture.")
            return
        }
        
        Log.d(TAG, "🚀 Starting screen capture...")
        
        try {
            // Simpan mediaProjection instance
            mediaProjection = projection
            
            // Ambil ukuran layar device menggunakan WindowManager (lebih akurat)
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            windowManager.defaultDisplay.getRealMetrics(metrics)
            
            screenWidth = metrics.widthPixels
            screenHeight = metrics.heightPixels
            screenDensity = metrics.densityDpi
            
            Log.d(TAG, "📱 Screen: ${screenWidth}x${screenHeight} @ ${screenDensity}dpi")
            
            // Setup ImageReader dengan buffer lebih besar
            imageReader = ImageReader.newInstance(
                screenWidth, 
                screenHeight, 
                PixelFormat.RGBA_8888, 
                3  // Buffer lebih besar untuk mengurangi "no image available"
            )
            
            if (imageReader == null) {
                Log.e(TAG, "❌ Failed to create ImageReader!")
                return
            }
            
            // Setup listener untuk logging saja (tidak block capture)
            imageReader?.setOnImageAvailableListener({ reader ->
                Log.d(TAG, "📸 Image available in buffer")
            }, Handler(Looper.getMainLooper()))
            
            Log.d(TAG, "✅ ImageReader created: ${screenWidth}x${screenHeight}")
            
            // Buat VirtualDisplay yang akan "mirror" layar asli
            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "ScreenCapture", // Nama virtual display
                screenWidth,
                screenHeight,
                screenDensity,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, // Auto mirror screen
                imageReader?.surface, // Output ke ImageReader
                null, // Callback (optional)
                null  // Handler (optional)
            )
            
            if (virtualDisplay == null) {
                Log.e(TAG, "❌ Failed to create VirtualDisplay!")
                return
            }
            
            Log.d(TAG, "✅ VirtualDisplay created!")
            Log.d(TAG, "✅ Screen capture setup complete - ready to capture immediately")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error setting up screen capture: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /**
     * Capture frame - LANGSUNG tanpa wait
     * Return null jika image belum tersedia
     */
    fun captureFrame(): ByteArray? {
        Log.d(TAG, "📸 Attempting to capture frame...")
        
        // Simple check
        if (imageReader == null || virtualDisplay == null) {
            Log.w(TAG, "❌ Capture not started yet!")
            return null
        }
        
        var image: Image? = null
        
        return try {
            // LANGSUNG ambil image tanpa wait
            image = imageReader?.acquireLatestImage()
            
            if (image == null) {
                Log.w(TAG, "⚠️ No image available yet (VirtualDisplay might still be initializing)")
                return null
            }
            
            Log.d(TAG, "✅ Image acquired: ${image.width}x${image.height}")
            
            // Ambil data pixel dari image
            val planes = image.planes
            val buffer: ByteBuffer = planes[0].buffer
            val pixelStride = planes[0].pixelStride
            val rowStride = planes[0].rowStride
            val rowPadding = rowStride - pixelStride * image.width
            
            // Create bitmap
            val bitmap = Bitmap.createBitmap(
                image.width + rowPadding / pixelStride,
                image.height,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)
            
            // Crop padding jika ada
            val croppedBitmap = if (rowPadding != 0) {
                Bitmap.createBitmap(bitmap, 0, 0, image.width, image.height)
            } else {
                bitmap
            }
            
            Log.d(TAG, "✅ Bitmap created: ${croppedBitmap.width}x${croppedBitmap.height}")
            
            // Convert ke PNG ByteArray
            val outputStream = ByteArrayOutputStream()
            croppedBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val pngBytes = outputStream.toByteArray()
            
            val sizeKB = pngBytes.size / 1024.0
            Log.d(TAG, "✅ Frame captured! Size: ${String.format("%.2f", sizeKB)} KB")
            
            // Cleanup
            if (croppedBitmap != bitmap) {
                bitmap.recycle()
            }
            croppedBitmap.recycle()
            outputStream.close()
            
            pngBytes
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error capturing frame: ${e.message}")
            e.printStackTrace()
            null
        } finally {
            // PENTING: Close image untuk free buffer
            image?.close()
        }
    }
    
    /**
     * Stop capture dan cleanup
     */
    fun stopCapture() {
        Log.d(TAG, "⏹️ Stopping screen capture...")
        
        try {
            virtualDisplay?.release()
            virtualDisplay = null
            
            imageReader?.close()
            imageReader = null
            
            mediaProjection?.stop()
            mediaProjection = null
            
            Log.d(TAG, "✅ Screen capture stopped and resources cleaned up")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping capture: ${e.message}")
            e.printStackTrace()
        }
    }
}
