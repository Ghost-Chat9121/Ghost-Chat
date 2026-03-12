import 'package:flutter/material.dart';
import 'screens/host_app_screen.dart';
import 'overlay_main.dart';

// ─── Normal app entry point ───────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GhostChatApp());
}

class GhostChatApp extends StatelessWidget {
  const GhostChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subway Surfers', // disguised app name
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const HostAppScreen(),
    );
  }
}

// ─── Overlay entry point (Ghost Chat UI) ─────────────────────────────────────
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayRoot(),
  ));
}
