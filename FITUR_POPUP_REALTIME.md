# 🚨 FITUR POPUP REALTIME OVERLAY - DOKUMENTASI LENGKAP

## 📋 DESKRIPSI FITUR

Fitur **Popup Realtime Overlay** adalah sistem peringatan yang muncul **langsung di atas aplikasi lain** (seperti TikTok, Instagram, dll) ketika konten berbahaya terdeteksi. Popup ini muncul REALTIME tanpa perlu user kembali ke aplikasi Reflvy.

---

## 🎯 TUJUAN

1. ⚡ **Intervensi Cepat**: Peringatan muncul langsung saat konten berbahaya terdeteksi
2. 👁️ **Always Visible**: Popup tampil di atas aplikasi manapun yang sedang dibuka
3. 🛡️ **Perlindungan Proaktif**: User langsung tahu ada konten berbahaya tanpa delay
4. 🏠 **Minimize Otomatis**: App berbahaya langsung di-minimize ke home screen

---

## 🏗️ ARSITEKTUR SISTEM

### **Flow Diagram:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER SIDE (Dart)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. AutoScreenshotService                                       │
│     └─> Capture screen setiap 5 detik                          │
│     └─> Analisis konten dengan AI                              │
│     └─> Jika berbahaya → Kirim ke OverlayService (Native)      │
│                                                                 │
│  2. OverlayService (Flutter)                                    │
│     └─> Method: showOverlay()                                   │
│     └─> Kirim intent ke Native Android                         │
│     └─> Listen event dari Native (EventChannel)                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    MethodChannel Intent
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   NATIVE ANDROID SIDE (Kotlin)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  3. MainActivity.kt                                             │
│     └─> Terima intent dari Flutter                             │
│     └─> Start OverlayService dengan data                       │
│                                                                 │
│  4. OverlayService.kt (Android Service)                         │
│     └─> Buat overlay window dengan WindowManager               │
│     └─> Tampilkan layout XML di atas app lain                  │
│     └─> Handle button click (Abaikan / Tutup Aplikasi)         │
│     └─> Broadcast hasil ke Flutter                             │
│     └─> Minimize app ke home screen                            │
│                                                                 │
│  5. reflvy_overlay.xml                                          │
│     └─> Layout UI popup (TextView, Button, CardView)           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    Broadcast Intent
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER SIDE (Dart)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  6. MainActivity.kt - BroadcastReceiver                         │
│     └─> Terima broadcast (USER_DISMISSED / USER_CLOSE_APP)     │
│     └─> Forward ke EventChannel                                │
│                                                                 │
│  7. AutoScreenshotService - Event Handler                       │
│     └─> Resume monitoring (isPaused = false)                   │
│     └─> Cancel timeout timer                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 FILE-FILE TERLIBAT

### **1. Flutter/Dart Files:**

#### **`lib/services/overlay_service.dart`** (73 baris)

**Fungsi:** Bridge antara Flutter dan Native Android untuk overlay

```dart
class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.reflvy.app/overlay');
  static const EventChannel _eventChannel = EventChannel('com.reflvy.app/overlay_events');

  // Cek permission SYSTEM_ALERT_WINDOW
  Future<bool> canDrawOverlays()

  // Buka settings untuk enable overlay permission
  Future<void> openOverlaySettings()

  // Tampilkan popup overlay di atas app lain
  Future<void> showOverlay({required String level, required String appName})

  // Listen event dari native (dismissed/close_app)
  Stream<Map<String, dynamic>> get overlayEvents
}
```

#### **`lib/services/auto_screenshot_service.dart`** (bagian overlay)

**Fungsi:** Koordinator utama untuk monitoring dan intervensi

```dart
// STEP 2: Check Overlay Permission
bool canDrawOverlays = await _overlayService.canDrawOverlays();

// STEP 3: Setup overlay event listener
_overlayEventSubscription = _overlayService.overlayEvents.listen((event) {
  _handleOverlayEvent(event);
});

// Tampilkan popup saat konten berbahaya terdeteksi
void _showInterventionPopup(ContentLevel level, String appName, Uint8List imageBytes) {
  isPaused.value = true; // Pause monitoring

  await _overlayService.showOverlay(
    level: levelString,
    appName: appName,
  );

  // Auto-resume setelah 10 detik jika tidak ada response
  _pauseTimeoutTimer = Timer(const Duration(seconds: 10), () {
    if (isPaused.value) {
      isPaused.value = false; // Auto-resume
    }
  });
}

// Handle event dari native
void _handleOverlayEvent(Map<String, dynamic> event) {
  _pauseTimeoutTimer?.cancel(); // Cancel timeout

  if (event['action'] == 'dismissed') {
    isPaused.value = false; // Resume monitoring
  } else if (event['action'] == 'close_app') {
    isPaused.value = false; // Resume monitoring
  }
}
```

---

### **2. Native Android Files:**

#### **`android/app/src/main/kotlin/.../MainActivity.kt`** (509 baris)

**Fungsi:** Bridge utama antara Flutter dan Native Android

**Channel Setup:**

```kotlin
private val OVERLAY_CHANNEL = "com.reflvy.app/overlay"
private val OVERLAY_EVENT_CHANNEL = "com.reflvy.app/overlay_events"

// EventChannel untuk broadcast overlay events
EventChannel(..., OVERLAY_EVENT_CHANNEL).setStreamHandler(...)

// BroadcastReceiver untuk terima event dari OverlayService
private val overlayBroadcastReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            OverlayService.BROADCAST_USER_DISMISSED -> {
                overlayEventSink?.success(mapOf("action" to "dismissed"))
            }
            OverlayService.BROADCAST_USER_CLOSE_APP -> {
                val appName = intent.getStringExtra("app_name") ?: "Unknown"
                overlayEventSink?.success(mapOf(
                    "action" to "close_app",
                    "app_name" to appName
                ))
            }
        }
    }
}
```

**Method Handler:**

```kotlin
MethodChannel(..., OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
    when (call.method) {
        "canDrawOverlays" -> {
            val canDraw = Settings.canDrawOverlays(this)
            result.success(canDraw)
        }

        "openOverlaySettings" -> {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
            result.success(null)
        }

        "showOverlay" -> {
            val level = call.argument<String>("level")
            val appName = call.argument<String>("app_name")

            val intent = Intent(this, OverlayService::class.java).apply {
                action = OverlayService.ACTION_SHOW_OVERLAY
                putExtra("level", level)
                putExtra("app_name", appName)
            }
            startService(intent)
            result.success(null)
        }
    }
}
```

---

#### **`android/app/src/main/kotlin/.../OverlayService.kt`** (243 baris)

**Fungsi:** Service Android untuk tampilkan overlay window

**Key Features:**

```kotlin
class OverlayService : Service() {
    companion object {
        const val ACTION_SHOW_OVERLAY = "..."
        const val ACTION_HIDE_OVERLAY = "..."
        const val BROADCAST_USER_DISMISSED = "...USER_DISMISSED"
        const val BROADCAST_USER_CLOSE_APP = "...USER_CLOSE_APP"
    }

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    // 1. Tampilkan overlay window
    private fun showOverlay(level: String, appName: String) {
        // Cek permission
        if (!Settings.canDrawOverlays(this)) {
            Log.e(TAG, "Overlay permission not granted!")
            return
        }

        // Buat view dari XML layout
        overlayView = createOverlayView(level, appName)

        // Setup window parameters
        val params = WindowManager.LayoutParams(
            MATCH_PARENT,
            MATCH_PARENT,
            TYPE_APPLICATION_OVERLAY, // API 26+
            FLAG_NOT_TOUCH_MODAL | FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        // Tampilkan overlay
        windowManager?.addView(overlayView, params)
    }

    // 2. Buat view dengan button handlers
    private fun createOverlayView(level: String, appName: String): View {
        val view = inflater.inflate(R.layout.reflvy_overlay, null)

        val btnIgnore = view.findViewById<Button>(R.id.btnIgnore)
        val btnClose = view.findViewById<Button>(R.id.btnClose)

        // Handler: User klik "Abaikan"
        btnIgnore.setOnClickListener {
            sendBroadcast(Intent(BROADCAST_USER_DISMISSED))
            hideOverlay()

            Handler(Looper.getMainLooper()).postDelayed({
                stopSelf() // Stop service
            }, 300)
        }

        // Handler: User klik "Tutup Aplikasi"
        btnClose.setOnClickListener {
            val closeIntent = Intent(BROADCAST_USER_CLOSE_APP).apply {
                putExtra("app_name", appName)
            }
            sendBroadcast(closeIntent)
            hideOverlay()

            // Minimize ke home screen
            val homeIntent = Intent(Intent.ACTION_MAIN)
            homeIntent.addCategory(Intent.CATEGORY_HOME)
            homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(homeIntent)

            Handler(Looper.getMainLooper()).postDelayed({
                stopSelf()
            }, 300)
        }

        // Hide button "Abaikan" jika level != LOW
        if (level != "LOW") {
            btnIgnore.visibility = View.GONE
        }

        return view
    }

    // 3. Hapus overlay
    private fun hideOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
    }
}
```

---

#### **`android/app/src/main/res/layout/reflvy_overlay.xml`** (200+ baris)

**Fungsi:** UI Layout untuk popup overlay

**Struktur:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout>
    <!-- Background semi-transparent -->
    <View android:background="#80000000" />

    <androidx.cardview.widget.CardView>
        <LinearLayout>
            <!-- Header -->
            <TextView android:id="@+id/tvTitle"
                      android:text="⚠️ KONTEN BERBAHAYA TERDETEKSI" />

            <!-- Badge Level (LOW/MEDIUM/HIGH) -->
            <TextView android:id="@+id/tvBadge" />

            <!-- Description -->
            <TextView android:id="@+id/tvDesc" />

            <!-- Warning Icon -->
            <ImageView android:src="@drawable/ic_warning" />

            <!-- Buttons -->
            <Button android:id="@+id/btnIgnore"
                    android:text="Abaikan"
                    android:visibility="visible" />

            <Button android:id="@+id/btnClose"
                    android:text="Tutup Aplikasi"
                    android:backgroundTint="@color/red" />
        </LinearLayout>
    </androidx.cardview.widget.CardView>
</FrameLayout>
```

---

#### **`android/app/src/main/AndroidManifest.xml`**

**Tambahan Permission & Service:**

```xml
<!-- Permission untuk tampilkan overlay di atas app lain -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

<application>
    <!-- Deklarasi OverlayService -->
    <service
        android:name=".OverlayService"
        android:enabled="true"
        android:exported="false" />
</application>
```

---

## 🔑 PERMISSION YANG DIBUTUHKAN

### **1. SYSTEM_ALERT_WINDOW (Overlay Permission)**

**Kenapa Diperlukan:**

- Untuk menampilkan popup di atas aplikasi lain (TikTok, Instagram, dll)
- Tanpa ini, popup hanya bisa tampil saat user kembali ke app Reflvy

**Cara Request:**

**Flutter Side:**

```dart
// Cek permission
bool canDrawOverlays = await _overlayService.canDrawOverlays();

if (!canDrawOverlays) {
  // Tampilkan dialog ke user
  Get.dialog(
    AlertDialog(
      title: Text('Permission Required'),
      content: Text('Aktifkan "Display over other apps"...'),
      actions: [
        ElevatedButton(
          onPressed: () => _overlayService.openOverlaySettings(),
          child: Text('Buka Settings'),
        ),
      ],
    ),
  );
}
```

**Native Android:**

```kotlin
// Cek permission (API 23+)
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    val canDraw = Settings.canDrawOverlays(context)
    if (!canDraw) {
        // Buka settings
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }
}
```

**Cara User Aktifkan:**

1. Buka **Settings** → **Apps** → **Special app access**
2. Pilih **Display over other apps**
3. Cari **Reflvy** atau **fitur_deteksi_gambar_ai**
4. Toggle **Allow display over other apps** → ON

---

### **2. Media Projection (Screen Capture)**

Sudah dijelaskan di dokumentasi sebelumnya.

---

## 🔄 FLOW LENGKAP DARI AWAL SAMPAI AKHIR

### **Scenario: Konten Berbahaya Terdeteksi di TikTok**

```
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: Monitoring Aktif                                        │
├─────────────────────────────────────────────────────────────────┤
│ • User buka TikTok                                              │
│ • AutoScreenshotService capture screen setiap 5 detik          │
│ • Deteksi app: "TikTok"                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: Analisis Konten                                         │
├─────────────────────────────────────────────────────────────────┤
│ • ContentAnalysisService.analyzeContent(imageBytes)            │
│ • Result: ContentLevel.HIGH (konten berbahaya!)                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: Pause Monitoring                                        │
├─────────────────────────────────────────────────────────────────┤
│ • isPaused.value = true                                         │
│ • Log: "⏸️ Pausing monitoring..."                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: Tampilkan Popup (Flutter → Native)                     │
├─────────────────────────────────────────────────────────────────┤
│ Flutter:                                                        │
│ • _overlayService.showOverlay(                                  │
│     level: "HIGH",                                              │
│     appName: "TikTok"                                           │
│   )                                                             │
│                                                                 │
│ Native (MainActivity.kt):                                       │
│ • Terima method call "showOverlay"                             │
│ • Start OverlayService dengan intent                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 5: Overlay Service Buat Window                            │
├─────────────────────────────────────────────────────────────────┤
│ OverlayService.kt:                                              │
│ • Cek Settings.canDrawOverlays() = true                        │
│ • Inflate layout: reflvy_overlay.xml                           │
│ • Setup WindowManager params (TYPE_APPLICATION_OVERLAY)        │
│ • windowManager.addView(overlayView, params)                   │
│                                                                 │
│ Log: "✅✅✅ OVERLAY DISPLAYED SUCCESSFULLY!"                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 6: Popup Muncul di Atas TikTok 🎯                         │
├─────────────────────────────────────────────────────────────────┤
│ User melihat popup dengan:                                      │
│ ┌──────────────────────────────────┐                           │
│ │ ⚠️ KONTEN BERBAHAYA TERDETEKSI    │                           │
│ │                                  │                           │
│ │ [ HIGH ]                         │                           │
│ │                                  │                           │
│ │ Terdeteksi konten berisiko tinggi│                           │
│ │ di TikTok!                       │                           │
│ │                                  │                           │
│ │ ⚠️ (Icon Warning)                │                           │
│ │                                  │                           │
│ │ [ Tutup Aplikasi ]               │ ← Only button (HIGH)      │
│ └──────────────────────────────────┘                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 7: Start Timeout Timer                                    │
├─────────────────────────────────────────────────────────────────┤
│ Flutter (AutoScreenshotService):                                │
│ • _pauseTimeoutTimer = Timer(10 seconds, () {                  │
│     if (isPaused.value) {                                       │
│       isPaused.value = false; // Auto-resume                   │
│     }                                                           │
│   })                                                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 8A: User Klik "Tutup Aplikasi"                            │
├─────────────────────────────────────────────────────────────────┤
│ OverlayService.kt:                                              │
│ • sendBroadcast(Intent(BROADCAST_USER_CLOSE_APP))              │
│ • hideOverlay()                                                 │
│ • startActivity(homeIntent) → Minimize ke home                 │
│ • stopSelf() after 300ms delay                                 │
│                                                                 │
│ Log: "🏠 User sent to home screen (minimize)"                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 9: Broadcast → MainActivity                               │
├─────────────────────────────────────────────────────────────────┤
│ MainActivity.kt - BroadcastReceiver:                            │
│ • onReceive(BROADCAST_USER_CLOSE_APP)                          │
│ • val appName = intent.getStringExtra("app_name") = "TikTok"  │
│ • overlayEventSink?.success(mapOf(                             │
│     "action" to "close_app",                                   │
│     "app_name" to "TikTok"                                     │
│   ))                                                            │
│                                                                 │
│ Log: "📤 Event sent to Flutter: close_app"                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 10: Flutter Handle Event                                  │
├─────────────────────────────────────────────────────────────────┤
│ AutoScreenshotService._handleOverlayEvent():                    │
│ • _pauseTimeoutTimer?.cancel() → Cancel timeout                │
│ • action = "close_app"                                         │
│ • isPaused.value = false → Resume monitoring                   │
│                                                                 │
│ Log: "✅ Monitoring RESUMED after closing app"                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ STEP 11: Monitoring Continue                                   │
├─────────────────────────────────────────────────────────────────┤
│ • User sekarang di home screen (TikTok ter-minimize)           │
│ • Monitoring resume, capture tiap 5 detik                      │
│ • Siap detect konten berbahaya lagi                            │
└─────────────────────────────────────────────────────────────────┘
```

---

### **Scenario Alternative: User Klik "Abaikan" (LOW Level Only)**

```
STEP 8B: User Klik "Abaikan"
├─ OverlayService.kt:
│  • sendBroadcast(Intent(BROADCAST_USER_DISMISSED))
│  • hideOverlay()
│  • stopSelf() after 300ms
│
├─ MainActivity.kt - BroadcastReceiver:
│  • onReceive(BROADCAST_USER_DISMISSED)
│  • overlayEventSink?.success(mapOf("action" to "dismissed"))
│
└─ AutoScreenshotService._handleOverlayEvent():
   • _pauseTimeoutTimer?.cancel()
   • isPaused.value = false → Resume monitoring
   • User tetap di TikTok (tidak di-minimize)
```

---

### **Scenario Fallback: Timeout (10 detik, tidak ada response)**

```
STEP 8C: Timeout Reached
├─ AutoScreenshotService:
│  • Timer(10 seconds) triggered
│  • Log: "⏰ Timeout reached! No overlay event received."
│  • isPaused.value = false → Auto-resume monitoring
│  • Log: "✅ Auto-resuming monitoring..."
│
└─ Monitoring continue tanpa user action
```

---

## 🛠️ DEBUGGING & LOGGING

### **Flutter Logs:**

```dart
// Auto screenshot service
print('🚨 DANGEROUS CONTENT DETECTED! Level: $levelLabel');
print('⏸️ Pausing monitoring...');
print('📢 Showing REALTIME overlay: $levelString');
print('✅ Overlay displayed, waiting for user action...');

// Event handler
print('📨 Overlay event received: $event');
print('ℹ️ User dismissed warning (LOW level)');
print('🏠 User chose to close app: $appName');
print('✅ Monitoring RESUMED after dismiss');

// Timeout
print('⏰ Timeout reached! No overlay event received.');
print('✅ Auto-resuming monitoring...');
```

### **Android Logs:**

```kotlin
// MainActivity.kt
Log.d(TAG, "📤 Starting OverlayService: level=$level, app=$appName")
Log.d(TAG, "📨📨📨 BroadcastReceiver.onReceive() called!")
Log.d(TAG, "✅ Received BROADCAST_USER_DISMISSED")
Log.d(TAG, "📤 Event sent to Flutter: dismissed")

// OverlayService.kt
Log.d(TAG, "✅ Overlay permission granted, proceeding...")
Log.d(TAG, "🎨 Overlay view created")
Log.d(TAG, "✅✅✅ OVERLAY DISPLAYED SUCCESSFULLY!")
Log.d(TAG, "ℹ️ User clicked 'Abaikan' button")
Log.d(TAG, "📤 Broadcast sent: $BROADCAST_USER_DISMISSED")
Log.d(TAG, "🏠 User sent to home screen (minimize)")
Log.d(TAG, "🛑 OverlayService destroyed")
```

### **Filter Logs:**

```bash
# Flutter logs
flutter run | grep "Overlay\|OVERLAY\|overlay\|Monitoring\|RESUME"

# Android logs
adb logcat | grep -E "OverlayService|MainActivity|📨|📤|✅"
```

---

## ⚠️ TROUBLESHOOTING

### **Problem 1: Popup Tidak Muncul**

**Symptom:**

- Log: "✅ Overlay displayed..." muncul
- Tapi tidak ada popup di layar

**Solution:**

```kotlin
// Cek permission
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
    if (!Settings.canDrawOverlays(this)) {
        Log.e(TAG, "❌ OVERLAY PERMISSION NOT GRANTED!")
        // Buka settings manual
    }
}

// Cek window type (harus TYPE_APPLICATION_OVERLAY untuk API 26+)
val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
} else {
    WindowManager.LayoutParams.TYPE_PHONE // Deprecated
}
```

---

### **Problem 2: Event Tidak Sampai ke Flutter**

**Symptom:**

- Log di OverlayService: "📤 Broadcast sent"
- Tapi tidak ada log di Flutter: "📨 Overlay event received"

**Solution:**

```kotlin
// MainActivity.kt - Pastikan receiver registered
if (!isOverlayReceiverRegistered) {
    val filter = IntentFilter().apply {
        addAction(OverlayService.BROADCAST_USER_DISMISSED)
        addAction(OverlayService.BROADCAST_USER_CLOSE_APP)
    }
    registerReceiver(overlayBroadcastReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    isOverlayReceiverRegistered = true
}

// Pastikan EventSink tidak null
if (overlayEventSink != null) {
    overlayEventSink?.success(payload)
} else {
    // Store pending event
    pendingOverlayEvent = payload
}
```

---

### **Problem 3: Monitoring Stuck di Paused**

**Symptom:**

- Log: "⏸️ Monitoring paused (popup is showing), skipping capture"
- Terus menerus, tidak resume

**Solution:**
✅ **Sudah diperbaiki dengan timeout timer!**

```dart
// Auto-resume after 10 seconds
_pauseTimeoutTimer = Timer(const Duration(seconds: 10), () {
  if (isPaused.value) {
    print('⏰ Timeout reached! Auto-resuming...');
    isPaused.value = false;
  }
});
```

---

### **Problem 4: Button Tidak Bisa Diklik**

**Symptom:**

- Popup muncul
- Tapi button tidak respond saat diklik

**Solution:**

```kotlin
// Hapus FLAG_NOT_FOCUSABLE dari window params
val params = WindowManager.LayoutParams(
    MATCH_PARENT,
    MATCH_PARENT,
    TYPE_APPLICATION_OVERLAY,
    // ❌ Jangan pakai: FLAG_NOT_FOCUSABLE
    FLAG_NOT_TOUCH_MODAL | FLAG_LAYOUT_IN_SCREEN, // ✅ Ini cukup
    PixelFormat.TRANSLUCENT
)
```

---

## 📊 PERFORMA & OPTIMASI

### **Memory Usage:**

- **OverlayService:** ~2-5 MB saat aktif
- **Layout inflating:** ~500 KB
- **WindowManager:** Minimal overhead

### **Response Time:**

- **Flutter → Native:** ~50-100ms (MethodChannel)
- **Overlay tampil:** ~100-200ms (WindowManager.addView)
- **Native → Flutter:** ~50-100ms (BroadcastReceiver + EventChannel)
- **Total:** ~200-400ms dari deteksi hingga popup muncul

### **Battery Impact:**

- Service hanya aktif saat popup muncul (~10-30 detik)
- Auto stopSelf() setelah user action
- Minimal battery drain

---

## 🔒 SECURITY & PRIVACY

### **Permission Security:**

1. **SYSTEM_ALERT_WINDOW** - User harus approve manual di Settings
2. Tidak bisa auto-grant programmatically
3. Android 10+ ada pembatasan untuk app dari overlay phishing

### **Data Privacy:**

- Screenshot **TIDAK** dikirim ke OverlayService (too large, TransactionTooLargeException)
- Hanya kirim: `level` (LOW/MEDIUM/HIGH) dan `appName` (String)
- Broadcast intent hanya di dalam app (RECEIVER_NOT_EXPORTED)

---

## 📈 FUTURE IMPROVEMENTS

### **Planned:**

1. ✅ ~~Auto-resume dengan timeout~~ (DONE)
2. 🔄 Vibration feedback saat popup muncul
3. 🔊 Sound alert (optional)
4. 📸 Tampilkan thumbnail screenshot di popup (compress dulu)
5. 📊 Statistics: berapa kali user dismiss vs tutup app
6. 🎨 Custom theme untuk popup (light/dark mode)

### **Ideas:**

- Multi-level intervention (warning sebelum block)
- Whitelist apps (jangan deteksi untuk app tertentu)
- Schedule monitoring (aktif hanya di jam tertentu)
- Parental control integration

---

## 📝 CHANGELOG

### **v1.2.0** (Current)

- ✅ Popup realtime overlay implementation
- ✅ Auto-resume monitoring dengan timeout 10 detik
- ✅ Minimize to home screen (bukan force close)
- ✅ Hapus dependency Accessibility Service
- ✅ Fix TransactionTooLargeException (no image transfer)

### **v1.1.0**

- ✅ Basic overlay popup
- ❌ Force close app dengan Accessibility Service (dihapus)
- ❌ Event tidak reliable (fixed di v1.2.0)

---

## 🎓 LEARNING RESOURCES

### **Android WindowManager:**

- https://developer.android.com/reference/android/view/WindowManager
- https://developer.android.com/guide/topics/ui/window-management

### **Flutter MethodChannel & EventChannel:**

- https://flutter.dev/docs/development/platform-integration/platform-channels
- https://api.flutter.dev/flutter/services/MethodChannel-class.html
- https://api.flutter.dev/flutter/services/EventChannel-class.html

### **Android BroadcastReceiver:**

- https://developer.android.com/guide/components/broadcasts

---

## 👥 CONTRIBUTORS

- **Developer:** Bagas & Arul
- **Project:** Reflvy - AI Content Detection
- **Repository:** CRXWFF/fitur_deteksi_gambar_ai
- **Branch:** bagas

---

## 📞 SUPPORT

Jika ada pertanyaan atau issue:

1. Cek TROUBLESHOOTING section di atas
2. Review logs (Flutter + Android)
3. Pastikan permission sudah diaktifkan
4. Test di device fisik (bukan emulator)

---

**Last Updated:** November 5, 2025
**Version:** 1.2.0
