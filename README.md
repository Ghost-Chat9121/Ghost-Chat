# 👻 Ghost Chat

> A hidden peer-to-peer chat application disguised as a "Subway Surfers" game.

Ghost Chat is a **fully encrypted, zero-storage P2P communication app** built with Flutter (Android). It runs invisibly inside a fake game UI and is activated through a secret 7-tap gesture. All communication happens directly between devices using WebRTC — no messages, files, or call recordings are ever stored on a server.

---

## 🎭 How the Disguise Works

The app appears as a harmless mobile game called **"Subway Surfers"** on the home screen. Inside this fake game UI:

1. Tap the **🎵 Music icon 7 times quickly** to reveal Ghost Chat as a floating overlay
2. The Ghost Chat UI slides up over the game
3. When dismissed, the app returns to looking like a normal game

The Ghost Chat overlay runs as a separate Flutter engine (`overlayMain` entrypoint) inside `OverlayActivity.kt`, completely isolated from the host game app.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 💬 **P2P Text Chat** | End-to-end encrypted messaging via WebRTC Data Channel |
| 📞 **Audio Calls** | Real-time audio calls with mute/speaker controls |
| 📹 **Video Calls** | HD video calls with camera toggle, flip, screen share |
| 📎 **File Sharing** | Send any file type (images, videos, docs) peer-to-peer |
| 🖥️ **Screen Sharing** | Share your screen during or outside of a call |
| 🔒 **Zero Server Storage** | Signaling server only relays connection info — no content stored |
| 💨 **Auto-Wipe** | All messages clear when either peer leaves the room |
| 👻 **Ghost Mode** | Hidden behind a fake game — invisible to casual observers |

---

## 🏗️ Architecture Overview

```
ghost_chat/
├── lib/
│   ├── main.dart                    # Two entrypoints: main() and overlayMain()
│   ├── app/
│   │   └── theme.dart               # GhostTheme design system (colors, buttons, inputs)
│   ├── models/
│   │   ├── message_model.dart       # ChatMessage + ChatMessageType enum
│   │   └── file_transfer_model.dart # FileTransfer progress tracking
│   ├── services/
│   │   ├── signaling_service.dart   # Socket.IO WebRTC signaling (offer/answer/ICE)
│   │   ├── webrtc_service.dart      # RTCPeerConnection, DataChannel, media tracks
│   │   └── overlay_service.dart     # MethodChannel bridge to launch/close OverlayActivity
│   ├── screens/
│   │   ├── host_app_screen.dart     # 🎮 Fake "Subway Surfers" UI (disguise)
│   │   ├── ghost_home_screen.dart   # Ghost Chat home — room ID entry
│   │   ├── chat_screen.dart         # Main P2P chat screen (text + file + call controls)
│   │   ├── call_screen.dart         # Audio/video call UI
│   │   ├── file_share_screen.dart   # File send/receive with inline previews
│   │   └── screen_share_screen.dart # Dedicated screen sharing UI
│   └── widgets/
│       ├── message_bubble.dart      # Chat bubble (text + image types)
│       ├── call_control_button.dart # Reusable call controls (mute, end, speaker)
│       └── secret_trigger_widget.dart # 7-tap secret gesture detector
├── android/app/src/main/
│   ├── kotlin/com/example/ghost_chat/
│   │   ├── MainActivity.kt          # Host app — overlay launch + foreground svc channels
│   │   ├── OverlayActivity.kt       # Runs overlayMain() Flutter engine
│   │   └── ScreenShareService.kt    # Foreground service for Android 14+ screen capture
│   └── AndroidManifest.xml
└── server/
    ├── server.js                    # Node.js Socket.IO signaling server
    └── package.json
```

### Connection Flow

```
Device A                    Signaling Server                    Device B
   |                      (ghost-chat-akdw.onrender.com)           |
   |── join-room ────────────────────────────────────────────────► |
   |                                                               |
   |◄─ peer-joined ────────────────────────────────────────────── |
   |                                                               |
   |──── WebRTC Offer ────────────────────────────────────────────►|
   |◄─── WebRTC Answer ─────────────────────────────────────────── |
   |◄──► ICE Candidates ─────────────────────────────────────────► |
   |                                                               |
   |◄═══════════ Direct P2P Connection (no server) ═══════════════►|
   |             (text • files • audio • video)                    |
```

---

## 🔑 Key Concepts

### Room System
- Users share a **6-character Room ID** (e.g., `A1B2C3`) out-of-band (verbally, via another app, etc.)
- Both users join the same room → WebRTC negotiation begins automatically
- Rooms hold a maximum of **2 peers**
- The room is destroyed when both peers disconnect

### WebRTC Data Channel
- Text messages and file transfers use a single **RTCDataChannel** named `ghost_data`
- The offerer (first peer to join) creates the data channel
- File chunks are sent as binary messages (16 KB each); `FILE_START:` and `FILE_END:` text frames wrap them

### Signaling Server
- Lives at `https://ghost-chat-akdw.onrender.com` (free Render.com instance — may have a 30s cold start)
- Only handles WebRTC offer/answer/ICE relay and call-request/accept/reject signaling
- **No messages, files, or media ever touch the server**

### Overlay System
- `flutter_overlay_window` package provides permission management
- The actual overlay runs as a separate `OverlayActivity` (a full Flutter `FlutterActivity`) via a `MethodChannel`
- `overlayMain()` is the separate Dart entrypoint for the overlay engine

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_webrtc` | WebRTC peer connection, media tracks, data channels |
| `socket_io_client` | Real-time signaling with the Node.js server |
| `flutter_overlay_window` | Overlay permission management |
| `permission_handler` | Camera, microphone, storage permissions |
| `file_picker` | Pick files from device storage |
| `image_picker` | Camera photo/video capture |
| `open_filex` | Open received files with the system viewer |
| `path_provider` | Get external storage directory for saving received files |
| `uuid` | Generate random room IDs and message IDs |
| `intl` | Format message timestamps |
| `provider` | State management (available, not yet used) |
| `audio_session` | Audio session routing for calls |
| `flutter_background` | Background processing support |

---

## 🛡️ Security Notes

- All media is **peer-to-peer** — the signaling server never sees content
- TURN servers (metered.ca) are used as relay fallback when direct P2P fails
- Messages **auto-wipe** when a peer leaves the room
- The app uses **STUN/TURN** for NAT traversal with credentials embedded in the app
- File names are **sanitized** on receive to prevent path traversal attacks

> ⚠️ **Note:** The embedded TURN server credentials in `webrtc_service.dart` are hardcoded. For production, rotate these credentials and consider fetching them from a secure backend.

---

## 📱 Platform Support

| Platform | Status |
|----------|--------|
| Android | ✅ Primary target |
| iOS | ⚠️ Not configured (overlay system is Android-only) |
| Web / Desktop | ❌ Not supported |

---

## 👥 Contributing

See [SETUP.md](./SETUP.md) for how to get the project running locally.
