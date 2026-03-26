# 🛠️ Ghost Chat — Developer Setup Guide

Everything a new developer needs to get Ghost Chat running locally from scratch.

---

## ✅ Prerequisites

Make sure the following are installed before you begin:

| Tool | Version | Check |
|------|---------|-------|
| Flutter SDK | ≥ 3.0.0 | `flutter --version` |
| Dart SDK | ≥ 3.0.0 (bundled with Flutter) | `dart --version` |
| Android Studio | Latest stable | — |
| Android SDK | API 26+ (Android 8.0) | Android Studio SDK Manager |
| Node.js | ≥ 18.x | `node --version` |
| npm | ≥ 9.x | `npm --version` |
| Git | Any recent | `git --version` |

> 💡 **Tip:** Run `flutter doctor` after installing Flutter — it will tell you exactly what is missing.

---

## 1. Clone the Repository

```bash
git clone <your-repo-url> ghost_chat
cd ghost_chat
```

---

## 2. Install Flutter Dependencies

```bash
flutter pub get
```

> ⚠️ `flutter_webrtc` is pulled directly from GitHub (`main` branch). This step may take a few minutes on first run as it clones the dependency.

If you see errors about the `flutter_webrtc` package, try:

```bash
flutter pub upgrade flutter_webrtc
```

---

## 3. Connect an Android Device (or Start an Emulator)

### Physical device (recommended)
1. Enable **Developer Options** on your Android phone (tap *Build Number* 7 times in Settings → About)
2. Enable **USB Debugging**
3. Connect via USB
4. Run `adb devices` to confirm the device is recognized

### Emulator
```bash
# List available emulators
flutter emulators

# Launch one
flutter emulators --launch <emulator_id>
```

> ⚠️ Camera, microphone, and screen share features require a **real device**. Emulators do not support hardware camera properly.

---

## 4. Run the Flutter App

```bash
flutter run
```

The app will launch as "**Subway Surfers**" — this is the disguise. See [Activating Ghost Chat](#activating-ghost-chat) below to open the real UI.

### Hot reload / Hot restart
- **Hot reload:** Press `r` in the terminal while the app is running
- **Hot restart:** Press `R`
- **Quit:** Press `q`

---

## 5. Run the Signaling Server Locally (Optional)

The app is pre-configured to use the hosted server at `https://ghost-chat-akdw.onrender.com` (free Render.com tier — may take ~30 seconds to wake up on first use).

To run your own local signaling server:

```bash
cd server
npm install
node server.js
```

The server starts on **port 3000** by default.

Then update the server URL in `lib/services/signaling_service.dart`:

```dart
// Change this line:
const String kSignalingServer = 'https://ghost-chat-akdw.onrender.com';

// To your local IP (find it with `ipconfig` on Windows or `ifconfig` on Mac/Linux):
const String kSignalingServer = 'http://192.168.x.x:3000';
```

> ⚠️ Both devices must be on the same network, or you must expose the server publicly (e.g., via [ngrok](https://ngrok.com/)).

---

## 6. Grant Required Permissions

On first launch, the app will request:

| Permission | Why |
|-----------|-----|
| Camera | Video calls and taking photos to share |
| Microphone | Audio calls |
| Display over other apps | Required for the Ghost Chat overlay to appear on top of the game UI |

> 📌 **Display over other apps** must be **manually granted** — Android will redirect you to the system settings page. This is required for the overlay to work.

---

## 7. Activating Ghost Chat

The app opens as a fake "Subway Surfers" game. To reveal Ghost Chat:

1. Open the app (it shows the fake game)
2. Locate the **🎵 Music** icon in the bottom settings bar
3. **Tap it 7 times quickly** (within 3 seconds between taps)
4. A strong haptic confirms the activation
5. Ghost Chat overlays on top of the game

> 💡 To close Ghost Chat, tap the **✕** button in the top-right corner of the Ghost Chat interface.

---

## 8. Testing the P2P Connection (Two-Device Test)

You need two Android devices (or one device + one emulator for basic data channel tests):

1. Open Ghost Chat on **both devices**
2. On **Device A**: tap **"Generate New Room"** — a 6-character code appears
3. Copy that code and enter it on **Device B** (or share it verbally)
4. Both tap **"Enter Ghost Room"**
5. A secure P2P connection is established — the status turns **🟢 green**
6. Start chatting, calling, or sharing files

---

## 9. Project Structure Quick Reference

```
lib/
├── main.dart                   ← App entrypoints (main + overlayMain)
├── app/theme.dart              ← All colors, text styles, button themes
├── models/                     ← Data classes (messages, file transfers)
├── services/
│   ├── signaling_service.dart  ← WebRTC signaling via Socket.IO
│   ├── webrtc_service.dart     ← Core WebRTC logic (data channel, audio, video)
│   └── overlay_service.dart   ← Launches/closes the Ghost Chat overlay
└── screens/
    ├── host_app_screen.dart    ← The fake game (disguise)
    ├── ghost_home_screen.dart  ← Ghost Chat home (room entry)
    ├── chat_screen.dart        ← Main chat UI (text + calls + file share)
    ├── call_screen.dart        ← Audio/video call UI
    ├── file_share_screen.dart  ← File send/receive
    └── screen_share_screen.dart← Screen sharing UI

android/app/src/main/kotlin/com/example/ghost_chat/
├── MainActivity.kt             ← Registers MethodChannels (overlay + screen share)
├── OverlayActivity.kt          ← Hosts the Ghost Chat Flutter engine
└── ScreenShareService.kt       ← Android foreground service for screen capture
```

---

## 10. Common Issues & Fixes

### ❌ "Cannot reach server. Retrying..."
- The free Render.com server may be asleep. **Wait 30 seconds** and try again.
- Or run the signaling server locally (see Step 5).

### ❌ Overlay doesn't appear after 7 taps
- Check that **"Display over other apps"** permission is granted in Android Settings → Apps → Subway Surfers → Permissions.
- On MIUI / Realme / ColorOS devices, also check "Background popup" settings.

### ❌ Audio not heard during calls
- Make sure the **speaker icon** is yellow (speaker on) in the call UI.
- On physical devices, check that the media volume is up.
- TURN server fallback activates automatically if direct WebRTC fails — give it 5–10 seconds.

### ❌ Screen share fails on Android 14+
- Ensure `FOREGROUND_SERVICE_MEDIA_PROJECTION` permission is in the manifest (it is by default).
- The `ScreenShareService` foreground notification must appear before `getDisplayMedia` is called — this is handled automatically.

### ❌ `flutter pub get` fails on `flutter_webrtc`
```bash
# Clear the pub cache and retry
flutter pub cache clean
flutter pub get
```

### ❌ Build fails with Kotlin/Gradle errors
```bash
cd android
./gradlew clean
cd ..
flutter build apk --debug
```

---

## 11. Building a Release APK

```bash
flutter build apk --release
```

The output APK is at:
```
build/app/outputs/flutter-apk/app-release.apk
```

> ⚠️ For release builds, you must configure a signing key. See [Flutter's deployment docs](https://docs.flutter.dev/deployment/android).

---

## 12. Useful Flutter Commands

```bash
# Run with verbose logs (helpful for debugging WebRTC)
flutter run --verbose

# Run on a specific device
flutter run -d <device-id>

# List connected devices
flutter devices

# Check for dependency issues
flutter pub deps

# Static analysis
dart analyze lib

# Run tests
flutter test
```

---

## 13. Key Configuration Points

| Setting | File | What to Change |
|---------|------|---------------|
| Signaling server URL | `lib/services/signaling_service.dart` line 4 | Point to your own server |
| TURN server credentials | `lib/services/webrtc_service.dart` lines 42–60 | Rotate for production |
| Secret tap count | `lib/screens/host_app_screen.dart` line 17 | Change `_requiredTaps` value |
| App disguise name | `android/app/src/main/AndroidManifest.xml` line 26 | `android:label` attribute |
| App icon | `assets/icon.jpg` | Replace file + run `flutter pub run flutter_launcher_icons` |

---

## 14. Architecture Notes for New Developers

### Two Flutter Engines
This app runs **two separate Flutter engines** in the same process:
1. **Main engine** (`main()`) → powers the fake game (`HostAppScreen`)
2. **Overlay engine** (`overlayMain()`) → powers Ghost Chat (`GhostHomeScreen`, `ChatScreen`, etc.)

These two engines do **not share state**. They communicate only via `MethodChannel` through native Kotlin code.

### WebRTC Flow
```
ChatScreen
  └─ creates SignalingService (Socket.IO connection)
  └─ creates WebRTCService (RTCPeerConnection)
       └─ onPeerJoined → createOffer() → creates DataChannel
       └─ onPeerAlready → waits for offer from first peer
       └─ onDataChannelOpen → enables message sending UI
       └─ call initiated → addMediaForCall() → renegotiate()
```

### Shared WebRTC Instance
`ChatScreen`, `CallScreen`, and `FileShareScreen` all share the **same `WebRTCService` instance**. This means:
- The data channel stays alive across calls
- Callbacks (`onTextMessage`, `onFileStart`, etc.) may be temporarily overridden by `FileShareScreen` and restored on pop
- `onConnectionStateChange` is re-wired after returning from `CallScreen`

---

> 📘 For full project context, see [README.md](./README.md)
