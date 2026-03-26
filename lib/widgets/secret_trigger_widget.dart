import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/overlay_service.dart';

class SecretTriggerWidget extends StatefulWidget {
  final Widget child;
  final int requiredTaps;
  final Duration resetDuration;

  const SecretTriggerWidget({
    super.key,
    required this.child,
    this.requiredTaps = 7,
    this.resetDuration = const Duration(seconds: 3),
  });

  @override
  State<SecretTriggerWidget> createState() => _SecretTriggerWidgetState();
}

class _SecretTriggerWidgetState extends State<SecretTriggerWidget> {
  int _tapCount = 0;
  DateTime? _lastTap;

  Future<void> _handleTap() async {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) > widget.resetDuration) {
      _tapCount = 0;
    }
    _tapCount++;
    _lastTap = now;

    // Subtle haptic feedback on each tap (doesn't alert others visually)
    HapticFeedback.selectionClick();

    if (_tapCount >= widget.requiredTaps) {
      _tapCount = 0;
      _lastTap = null;
      HapticFeedback.heavyImpact(); // confirms launch
      await OverlayService.showGhostChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }
}
