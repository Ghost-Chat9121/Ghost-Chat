import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/overlay_service.dart'; // ✅ only import needed

class HostAppScreen extends StatefulWidget {
  const HostAppScreen({super.key});
  @override
  State<HostAppScreen> createState() => _HostAppScreenState();
}

class _HostAppScreenState extends State<HostAppScreen> {
  int _score = 0;

  // ─── Secret tap counter ────────────────────────────────────────────────────
  int _tapCount = 0;
  DateTime? _lastTap;
  static const int _requiredTaps = 7;

  @override
  void initState() {
    super.initState();
    // ✅ Request overlay permission on launch via OverlayService
    OverlayService.requestPermission();
  }

  Future<void> _handleMusicTap() async {
    final now = DateTime.now();

    // Reset counter if taps are too slow
    if (_lastTap != null &&
        now.difference(_lastTap!) > const Duration(seconds: 3)) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTap = now;

    // Light haptic on every tap
    // ✅ Realme devices need vibration instead of haptic feedback
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    debugPrint('👆 Tap count: $_tapCount / $_requiredTaps');

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      _lastTap = null;
      // Strong haptic confirming launch
      HapticFeedback.heavyImpact();
      // ✅ All permission + isActive checks handled inside OverlayService
      await OverlayService.showGhostChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Top bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🏄 SUBWAY SURFERS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Score: $_score',
                      style:
                          const TextStyle(color: Colors.yellow, fontSize: 16),
                    ),
                  ],
                ),
              ),

              // ─── Fake game area ────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🏃', style: TextStyle(fontSize: 80)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => setState(() => _score += 100),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'PLAY',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Settings bar ──────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  border: const Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _settingBtn(Icons.vibration, 'Vibrate', null),

                    // ✅ MUSIC ICON — 7-tap secret trigger
                    GestureDetector(
                      onTap: _handleMusicTap,
                      behavior: HitTestBehavior.opaque,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note,
                              color: Colors.white70, size: 28),
                          SizedBox(height: 4),
                          Text(
                            'Music',
                            style:
                                TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),

                    _settingBtn(Icons.volume_up, 'Sound', null),
                    _settingBtn(Icons.leaderboard, 'Ranks', null),
                    _settingBtn(Icons.settings, 'Settings', null),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingBtn(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
