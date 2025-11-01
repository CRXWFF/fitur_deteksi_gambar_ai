package com.example.fitur_deteksi_gambar_ai

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log

class AppDetectionHelper(private val context: Context) {
    
    private val TAG = "AppDetectionHelper"
    
    private val usageStatsManager: UsageStatsManager? by lazy {
        context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
    }
    
    private val packageManager: PackageManager by lazy {
        context.packageManager
    }
    
    // Map package name ke app name yang user-friendly
    private val appNameMap = mapOf(
        "com.zhiliaoapp.musically" to "TikTok",
        "com.ss.android.ugc.trill" to "TikTok Lite",
        "com.google.android.youtube" to "YouTube",
        "com.instagram.android" to "Instagram",
        "com.facebook.katana" to "Facebook",
        "com.whatsapp" to "WhatsApp",
        "com.twitter.android" to "Twitter/X",
        "com.snapchat.android" to "Snapchat",
        "com.netflix.mediaclient" to "Netflix",
        "com.spotify.music" to "Spotify",
        "com.android.chrome" to "Chrome",
        "com.google.android.gm" to "Gmail",
        "com.google.android.apps.maps" to "Google Maps",
        "com.linkedin.android" to "LinkedIn",
        "com.pinterest" to "Pinterest",
        "com.reddit.frontpage" to "Reddit",
        "com.telegram.messenger" to "Telegram",
        "us.zoom.videomeetings" to "Zoom",
        "com.google.android.apps.messaging" to "Messages",
        "com.android.settings" to "Settings"
    )
    
    /**
     * Check if app has USAGE_STATS permission
     */
    fun hasUsageStatsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
            val hasPermission = mode == AppOpsManager.MODE_ALLOWED
            Log.d(TAG, "Usage Stats Permission: $hasPermission")
            hasPermission
        } else {
            true
        }
    }
    
    /**
     * Open settings to grant USAGE_STATS permission
     */
    fun openUsageStatsSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
            Log.d(TAG, "Opened Usage Stats Settings")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening settings: ${e.message}")
        }
    }
    
    /**
     * Get current foreground app package name
     */
    fun getCurrentForegroundApp(): String? {
        if (!hasUsageStatsPermission()) {
            Log.w(TAG, "No Usage Stats permission")
            return null
        }
        
        try {
            val currentTime = System.currentTimeMillis()
            val queryUsageStats = usageStatsManager?.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                currentTime - 1000 * 60, // Last 60 seconds
                currentTime
            )
            
            if (queryUsageStats.isNullOrEmpty()) {
                Log.w(TAG, "No usage stats found")
                return null
            }
            
            // Sort by last time used and filter out this app
            val sortedStats = queryUsageStats
                .filter { it.packageName != context.packageName } // Exclude this app
                .sortedByDescending { it.lastTimeUsed }
            
            // Get the most recent app
            val recentApp = sortedStats.firstOrNull()
            val packageName = recentApp?.packageName
            
            Log.d(TAG, "Current foreground app: $packageName")
            return packageName
            
        } catch (e: Exception) {
            Log.e(TAG, "Error getting foreground app: ${e.message}")
            return null
        }
    }
    
    /**
     * Get app name from package name
     */
    fun getAppNameFromPackage(packageName: String?): String {
        if (packageName.isNullOrEmpty()) {
            return "Unknown"
        }
        
        // Check in our mapping first
        appNameMap[packageName]?.let { 
            Log.d(TAG, "Found in map: $packageName -> $it")
            return it 
        }
        
        // Try to get from package manager
        return try {
            val appInfo: ApplicationInfo = packageManager.getApplicationInfo(packageName, 0)
            val appName = packageManager.getApplicationLabel(appInfo).toString()
            Log.d(TAG, "Got from PM: $packageName -> $appName")
            appName
        } catch (e: PackageManager.NameNotFoundException) {
            val fallback = packageName.split(".").lastOrNull()?.replaceFirstChar { 
                if (it.isLowerCase()) it.titlecase() else it.toString() 
            } ?: "Unknown"
            Log.d(TAG, "Fallback: $packageName -> $fallback")
            fallback
        }
    }
    
    /**
     * Get current app name (combined method)
     */
    fun getCurrentAppName(): String {
        val packageName = getCurrentForegroundApp()
        val appName = getAppNameFromPackage(packageName)
        Log.d(TAG, "getCurrentAppName: $appName")
        return appName
    }
}
