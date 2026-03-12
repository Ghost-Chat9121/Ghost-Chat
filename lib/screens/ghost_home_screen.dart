import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/overlay_service.dart';
import 'chat_screen.dart';

class GhostHomeScreen extends StatefulWidget {
  const GhostHomeScreen({super.key});
  @override
  State<GhostHomeScreen> createState() => _GhostHomeScreenState();
}

class _GhostHomeScreenState extends State<GhostHomeScreen>
    with WidgetsBindingObserver {
  final _roomController = TextEditingController();
  final _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Auto-generate a userId
    _userIdController.text = const Uuid().v4().substring(0, 8);
  }

  // ─── Auto-close overlay when app is minimized ─────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      OverlayService.closeGhostChat();
    }
  }

  void _joinRoom() {
    final roomId = _roomController.text.trim();
    final userId = _userIdController.text.trim();
    if (roomId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, userId: userId),
      ),
    );
  }

  void _createRoom() {
    _roomController.text = const Uuid().v4().substring(0, 6).toUpperCase();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _roomController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Header with close button ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '👻 Ghost Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => OverlayService.closeGhostChat(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Peer-to-peer • No storage • No trace',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
              const SizedBox(height: 40),

              // ─── Room ID field ────────────────────────────────────────────
              _buildLabel('Room ID'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          _roomController, 'Enter or generate room ID')),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _createRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    child: const Text('New',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── User ID field ────────────────────────────────────────────
              _buildLabel('Your ID (auto-generated)'),
              const SizedBox(height: 8),
              _buildTextField(_userIdController, 'User ID'),
              const SizedBox(height: 40),

              // ─── Join button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _joinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Enter Ghost Room',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const Spacer(),
              const Center(
                child: Text(
                  '🔒 All data is end-to-end, peer-to-peer.\nNothing is ever saved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) =>
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13));

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
