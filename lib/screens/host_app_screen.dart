import 'package:flutter/material.dart';
import '../widgets/secret_trigger_widget.dart';

class HostAppScreen extends StatelessWidget {
  const HostAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade900,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Center(
              child: Text(
                '🏄 SUBWAY SURFERS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            const Spacer(),
            // ─── Settings Row ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSettingIcon(Icons.vibration, 'Vibrate'),
                  // ⬇️ SECRET TRIGGER — tap this icon 7 times quickly
                  SecretTriggerWidget(
                    requiredTaps: 7,
                    child: _buildSettingIcon(Icons.music_note, 'Music'),
                  ),
                  _buildSettingIcon(Icons.volume_up, 'Sound'),
                  _buildSettingIcon(Icons.notifications, 'Alerts'),
                ],
              ),
            ),
            const Spacer(),
            // Fake play button
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                padding:
                    const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                'PLAY',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 36),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
