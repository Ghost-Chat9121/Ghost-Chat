import 'package:flutter/material.dart';
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

    // Reset counter if too much time has passed
    if (_lastTap != null && now.difference(_lastTap!) > widget.resetDuration) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTap = now;

    if (_tapCount >= widget.requiredTaps) {
      _tapCount = 0;
      _lastTap = null;
      await OverlayService.showGhostChat(); // 🔥 LAUNCH GHOST CHAT
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: widget.child,
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/overlay_service.dart';

class SecretTriggerWidget extends StatefulWidget {
  const SecretTriggerWidget({
    super.key,
    required this.child,
    this.requiredTaps = 7,
    this.resetDelay = const Duration(seconds: 2),
  });

  final Widget child;
  final int requiredTaps;
  final Duration resetDelay;

  @override
  State<SecretTriggerWidget> createState() => _SecretTriggerWidgetState();
}

class _SecretTriggerWidgetState extends State<SecretTriggerWidget> {
  int _tapCount = 0;
  Timer? _resetTimer;

  Future<void> _handleTap() async {
    _resetTimer?.cancel();
    _tapCount += 1;

    if (_tapCount >= widget.requiredTaps) {
      _tapCount = 0;
      await OverlayService.showGhostChat();
      return;
    }

    _resetTimer = Timer(widget.resetDelay, () {
      _tapCount = 0;
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}
