# 🎯 REALTIME OVERLAY SYSTEM - COMPLETE IMPLEMENTATION

## 📋 OVERVIEW

Sistem monitoring dengan popup REALTIME yang muncul langsung di atas TikTok/Instagram saat konten berbahaya terdeteksi.

---

## 🔑 3 PERMISSION YANG DIPERLUKAN

### 1. **Screen Capture** (MediaProjection)

- **Tujuan**: Capture full screen setiap 5 detik
- **Request**: Otomatis saat klik "Start Monitoring"
- **Dialog**: System dialog "Start capturing screen?"

### 2. **Display Over Other Apps** (SYSTEM_ALERT_WINDOW)

- **Tujuan**: Popup REALTIME di atas TikTok/Instagram
- **Request**: Dialog konfirmasi sebelum monitoring mulai
- **Settings**: Settings > Apps > Reflvy > Display over other apps > ON

### 3. **Accessibility Service**

- **Tujuan**: Force close aplikasi berbahaya
- **Request**: Dialog konfirmasi sebelum monitoring mulai
- **Settings**: Settings > Accessibility > Reflvy > ON

---

## 🎬 FLOW LENGKAP

```
USER KLIK "START MONITORING"
   ↓
┌─────────────────────────────────────┐
│ STEP 1: Check Screen Capture        │
│ ✅ Auto request (system dialog)     │
│ ❌ Jika deny → Stop, show error     │
└─────────────────────────────────────┘
   ↓
┌─────────────────────────────────────┐
│ STEP 2: Check Overlay Permission    │
│ ✅ Jika sudah enable → Continue     │
│ ⚠️ Jika belum:                      │
│    - Show dialog konfirmasi         │
│    - User pilih "Buka Settings"     │
│    - User enable manual             │
│    - User balik ke app              │
│    - Klik "Start Monitoring" lagi   │
└─────────────────────────────────────┘
   ↓
┌─────────────────────────────────────┐
│ STEP 3: Check Accessibility         │
│ ✅ Jika sudah enable → Continue     │
│ ⚠️ Jika belum:                      │
│    - Show dialog konfirmasi         │
│    - User pilih "Buka Settings"     │
│    - User enable "Reflvy"           │
│    - User balik ke app              │
│    - Klik "Start Monitoring" lagi   │
└─────────────────────────────────────┘
   ↓
┌─────────────────────────────────────┐
│ STEP 4: Setup Overlay Listener      │
│ - Subscribe to EventChannel         │
│ - Ready to receive user actions     │
└─────────────────────────────────────┘
   ↓
┌─────────────────────────────────────┐
│ STEP 5: START MONITORING ✅         │
│ - Timer: Capture setiap 5 detik     │
│ - AI Analysis: Random dummy          │
│ - 40% chance detect berbahaya       │
└─────────────────────────────────────┘
   ↓
USER BUKA TIKTOK
   ↓
┌─────────────────────────────────────┐
│ TIMER CAPTURE (5 detik)             │
│ - Detect current app: TikTok        │
│ - Capture full screen               │
│ - AI analysis (dummy: 40% chance)   │
└─────────────────────────────────────┘
   ↓
JIKA BERBAHAYA (LOW/MEDIUM/HIGH)
   ↓
┌─────────────────────────────────────┐
│ isPaused = true ⏸️                  │
│ - Stop capture sementara            │
│ - Timer tetap jalan                 │
└─────────────────────────────────────┘
   ↓
┌─────────────────────────────────────┐
│ SHOW OVERLAY REALTIME 🚨            │
│ ✨ POPUP MUNCUL DI ATAS TIKTOK! ✨  │
│                                      │
│ - Native Android window overlay     │
│ - Type: TYPE_APPLICATION_OVERLAY    │
│ - Level badge: LOW/MEDIUM/HIGH      │
│ - App name: TikTok                  │
│                                      │
│ LOW:                                 │
│   [Abaikan] [Tutup Aplikasi]        │
│                                      │
│ MEDIUM/HIGH:                         │
│   [Tutup Aplikasi]                  │
└─────────────────────────────────────┘
   ↓
USER KLIK TOMBOL
   ↓
┌─────────────────────────────────────┐
│ NATIVE BROADCAST EVENT               │
│ - OverlayService → BroadcastReceiver│
│ - MainActivity → EventChannel        │
│ - Flutter → _handleOverlayEvent()   │
└─────────────────────────────────────┘
   ↓
JIKA "ABAIKAN" (LOW only)
   ↓
┌─────────────────────────────────────┐
│ - isPaused = false ✅               │
│ - User tetap di TikTok              │
│ - Monitoring RESUME                 │
└─────────────────────────────────────┘
   ↓
JIKA "TUTUP APLIKASI"
   ↓
┌─────────────────────────────────────┐
│ FORCE CLOSE APP 🚫                  │
│ - Get package name                  │
│ - Call Accessibility Service        │
│ - Runtime.exec("am force-stop ...")  │
│ - TikTok TERTUTUP                   │
│ - isPaused = false ✅               │
│ - Monitoring RESUME                 │
└─────────────────────────────────────┘
   ↓
5 DETIK KEMUDIAN
   ↓
┌─────────────────────────────────────┐
│ TIMER CAPTURE LAGI                  │
│ - isPaused = false → Lanjut         │
│ - Detect current app                │
│ - Capture & analyze                 │
│ - Dummy random lagi (40% chance)    │
│ - Popup bisa muncul lagi!           │
└─────────────────────────────────────┘
```

---

## 🛠️ KOMPONEN TEKNIS

### 1. **Flutter Side**

#### `auto_screenshot_service.dart`

```dart
startAutoScreenshot() {
  // Check 3 permissions
  // Setup overlay listener
  // Start timer
  // First capture
}

_captureAndSave() {
  if (isPaused) return; // Skip saat popup

  // Detect app
  // Capture frame
  // AI analysis

  if (berbahaya) {
    isPaused = true; // Pause
    showOverlay(); // Tampilkan popup REALTIME
  }
}

_handleOverlayEvent(event) {
  if (dismissed) {
    isPaused = false; // Resume
  }

  if (close_app) {
    forceCloseApp();
    isPaused = false; // Resume
  }
}
```

#### `overlay_service.dart`

```dart
canDrawOverlays() → Check permission
openOverlaySettings() → Buka Settings
showOverlay() → Kirim intent ke native
overlayEvents → Stream<Map> from EventChannel
```

### 2. **Native Android Side**

#### `MainActivity.kt`

```kotlin
// EventChannel untuk overlay events
EventChannel(OVERLAY_EVENT_CHANNEL)
  .setStreamHandler { ... }

// BroadcastReceiver
overlayBroadcastReceiver.onReceive() {
  overlayEventSink.success(event)
}

// MethodChannel untuk overlay
"showOverlay" → startService(OverlayService)
"hideOverlay" → stopService
"canDrawOverlays" → Settings.canDrawOverlays()
```

#### `OverlayService.kt`

```kotlin
showOverlay() {
  // Buat native window overlay
  windowManager.addView(overlayView, params)
}

createOverlayView() {
  // LinearLayout dengan:
  // - Icon warning
  // - Title
  // - Level badge (warna)
  // - App name
  // - Button(s)
}

// Button onClick
sendBroadcast(BROADCAST_USER_DISMISSED)
sendBroadcast(BROADCAST_USER_CLOSE_APP)
```

---

## 🎨 UI OVERLAY

```
┌─────────────────────────────────────┐
│                                      │
│            ⚠️                       │
│     (Icon Warning - Glow effect)    │
│                                      │
│  ⚠️ KONTEN BERBAHAYA TERDETEKSI     │
│                                      │
│      ┌──────────────┐               │
│      │ LEVEL: HIGH  │  ← Badge merah│
│      └──────────────┘               │
│                                      │
│      Aplikasi: TikTok                │
│                                      │
│   ┌────────────────────────┐        │
│   │   Tutup Aplikasi       │        │
│   └────────────────────────┘        │
│                                      │
│   (Untuk LOW saja ada "Abaikan")    │
│                                      │
└─────────────────────────────────────┘
```

### Color Scheme:

- **LOW**: Kuning (#FFC107)
- **MEDIUM**: Orange (#FF9800)
- **HIGH**: Merah (#F44336)

---

## 🧪 TESTING CHECKLIST

### Phase 1: Permission Setup

- [ ] Klik "Start Monitoring"
- [ ] Dialog screen capture muncul → Allow
- [ ] Dialog overlay permission muncul → Buka Settings
- [ ] Enable "Display over other apps" → Balik ke app
- [ ] Klik "Start Monitoring" lagi
- [ ] Dialog accessibility muncul → Buka Settings
- [ ] Enable "Reflvy" di Accessibility → Balik ke app
- [ ] Klik "Start Monitoring" lagi
- [ ] Monitoring mulai ✅

### Phase 2: Realtime Overlay

- [ ] Buka TikTok
- [ ] Tunggu ~5-10 detik (40% chance popup)
- [ ] **POPUP MUNCUL DI ATAS TIKTOK** (bukan di app Flutter!)
- [ ] Cek level badge (LOW/MEDIUM/HIGH)
- [ ] Cek app name (TikTok)

### Phase 3: User Action - Abaikan (LOW)

- [ ] Klik "Abaikan"
- [ ] Popup hilang
- [ ] User tetap di TikTok
- [ ] Tunggu 5 detik → Capture lagi
- [ ] Log: "✅ Monitoring RESUMED"

### Phase 4: User Action - Tutup Aplikasi

- [ ] Klik "Tutup Aplikasi"
- [ ] TikTok TERTUTUP paksa
- [ ] Balik ke home screen
- [ ] Monitoring tetap jalan
- [ ] Log: "✅ Monitoring RESUMED"

### Phase 5: Continuous Monitoring

- [ ] Buka TikTok lagi
- [ ] Tunggu popup muncul lagi (40% chance)
- [ ] Test dismiss → Resume → Capture lagi
- [ ] Test close → Resume → Capture lagi

---

## 📊 EXPECTED LOGS

```
🚀 Starting AUTO SCREENSHOT MONITORING...
🔑 Checking all permissions...
1️⃣ Checking Screen Capture permission...
✅ Screen Capture permission granted
2️⃣ Checking Overlay permission...
✅ Overlay permission granted
3️⃣ Checking Accessibility permission...
✅ Accessibility permission granted
4️⃣ Setting up overlay event listener...
✅ Overlay event listener ready
✅ ALL PERMISSIONS GRANTED! Starting monitoring...
⏳ Waiting ~1.5s for VirtualDisplay warm-up...
📸 Starting first actual capture...

📱 Current app: TikTok
🔍 Analyzing content...
📊 Analysis result: MEDIUM
🚨 DANGEROUS CONTENT DETECTED! Level: MEDIUM
⏸️ Pausing monitoring...
📢 Showing REALTIME overlay: MEDIUM
✅ Overlay displayed, waiting for user action...

⏸️ Monitoring paused (popup is showing), skipping capture
⏸️ Monitoring paused (popup is showing), skipping capture

📨 Overlay event received: {action: close_app, app_name: TikTok}
🚫 User chose to close app: TikTok
🔪 Force closing: TikTok
📦 Package name: com.zhiliaoapp.musically
✅ App closed successfully!
✅ Monitoring RESUMED after closing app

📱 Current app: Launcher
🔍 Analyzing content...
📊 Analysis result: SAFE
✅ Content is SAFE, no intervention needed
```

---

## 🚨 TROUBLESHOOTING

### 1. Popup Tidak Muncul

**Problem**: Overlay permission belum aktif
**Fix**:

- Buka Settings > Apps > Reflvy
- Display over other apps > ON

### 2. Popup Muncul di App, Bukan di TikTok

**Problem**: EventChannel belum setup atau permission tidak aktif
**Fix**:

- Restart app
- Check permission lagi

### 3. isPaused Tetap True

**Problem**: EventChannel tidak menerima broadcast
**Fix**:

- Check log untuk "📨 Overlay event received"
- Jika tidak ada → Restart app

### 4. Force Close Tidak Jalan

**Problem**: Accessibility Service belum aktif
**Fix**:

- Settings > Accessibility > Reflvy > ON
- Restart app

### 5. Monitoring Tidak Resume

**Problem**: `_handleOverlayEvent` tidak dipanggil
**Fix**:

- Check subscription di `startAutoScreenshot()`
- Pastikan `_overlayEventSubscription` tidak null

---

## 🎯 NEXT STEPS

### After Testing:

1. **Replace AI Dummy** dengan real API:

   - Google Vision API
   - AWS Rekognition
   - Custom ML model

2. **Improve Overlay UI**:

   - Add blur background
   - Add image preview
   - Add animation

3. **Add Settings**:

   - Sensitivity level (easy/medium/hard)
   - Whitelist apps
   - Custom timer interval

4. **Add Analytics**:
   - Track total detections
   - Track app usage
   - Generate reports

---

**Created**: November 5, 2025
**Status**: ✅ Ready for Testing
