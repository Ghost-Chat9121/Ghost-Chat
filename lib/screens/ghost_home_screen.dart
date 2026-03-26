import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../app/theme.dart';
import '../services/overlay_service.dart';
import 'chat_screen.dart';

class GhostHomeScreen extends StatefulWidget {
  const GhostHomeScreen({super.key});
  @override
  State<GhostHomeScreen> createState() => _GhostHomeScreenState();
}

class _GhostHomeScreenState extends State<GhostHomeScreen>
    with WidgetsBindingObserver {
  final _roomCtrl = TextEditingController();
  final String _myId = const Uuid().v4().substring(0, 8).toUpperCase();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ ONLY close overlay when app is completely killed from recents
    // paused = background (WhatsApp behavior — keep alive)
    // detached = fully killed — wipe everything
    if (state == AppLifecycleState.detached) {
      OverlayService.closeGhostChat();
    }
  }

  void _generateRoom() {
    _roomCtrl.text = const Uuid().v4().substring(0, 6).toUpperCase();
  }

  void _copyRoom() {
    Clipboard.setData(ClipboardData(text: _roomCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Room ID copied to clipboard'),
        duration: Duration(seconds: 1),
        backgroundColor: GhostTheme.accent,
      ),
    );
  }

  void _joinRoom() {
    final roomId = _roomCtrl.text.trim().toUpperCase();
    if (roomId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, myId: _myId),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GhostTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GhostTheme.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('👻', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ghost Chat',
                            style: TextStyle(
                                color: GhostTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text('Peer-to-peer · No storage · No trace',
                            style: TextStyle(
                                color: GhostTheme.green, fontSize: 11)),
                      ],
                    ),
                  ]),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: GhostTheme.textSecondary),
                    onPressed: () => OverlayService.closeGhostChat(),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ─── My ID chip ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GhostTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GhostTheme.border),
                ),
                child: Row(children: [
                  const Icon(Icons.fingerprint,
                      color: GhostTheme.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Text('Your ID: $_myId',
                      style: const TextStyle(
                          color: GhostTheme.textSecondary,
                          fontSize: 13,
                          fontFamily: 'monospace')),
                ]),
              ),

              const SizedBox(height: 24),

              // ─── Room ID field ───────────────────────────────────────
              const Text('Room ID',
                  style: TextStyle(
                      color: GhostTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _roomCtrl,
                    style: const TextStyle(
                        color: GhostTheme.textPrimary,
                        fontFamily: 'monospace',
                        fontSize: 16,
                        letterSpacing: 2),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Enter room code...',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Copy button
                IconButton(
                  onPressed: _copyRoom,
                  icon: const Icon(Icons.copy, color: GhostTheme.textSecondary),
                  style: IconButton.styleFrom(
                    backgroundColor: GhostTheme.card,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]),

              const SizedBox(height: 12),

              // ─── Generate button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _generateRoom,
                  icon: const Icon(Icons.add,
                      color: GhostTheme.accentLight, size: 18),
                  label: const Text('Generate New Room',
                      style: TextStyle(color: GhostTheme.accentLight)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: GhostTheme.accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Join button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _joinRoom,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Enter Ghost Room'),
                ),
              ),

              const Spacer(),

              // ─── Footer ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: GhostTheme.green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'End-to-end P2P • Session auto-wipes on close',
                    style: TextStyle(color: GhostTheme.textHint, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
