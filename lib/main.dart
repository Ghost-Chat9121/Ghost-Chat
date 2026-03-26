import 'package:flutter/material.dart';
import 'app/theme.dart'; // BUG 12 FIX
import 'screens/host_app_screen.dart';
import 'screens/ghost_home_screen.dart';
import 'services/overlay_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HostApp());
}

class HostApp extends StatelessWidget {
  const HostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subway Surfers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const HostAppScreen(),
    );
  }
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  OverlayService.markAsOverlayContext(); // ✅ marks this as overlay engine
  // BUG 12 FIX: Apply GhostTheme.dark so custom input/button/appbar styles take effect
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: GhostTheme.dark,
      home: const GhostHomeScreen(),
    ),
  );
}
