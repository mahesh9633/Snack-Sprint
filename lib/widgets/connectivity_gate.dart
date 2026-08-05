import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../config/app_color.dart';

/// Wrap your app's body (or any screen) with this widget.
///
/// While offline, it swaps everything for ONE clean "You're offline"
/// page instead of every child screen showing its own broken-image /
/// wifi-off error individually.
///
/// The moment the connection returns, it calls [onReconnected]
/// automatically — no retry button needed — then reveals the real
/// content again.
class ConnectivityGate extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReconnected;

  const ConnectivityGate({
    super.key,
    required this.child,
    this.onReconnected,
  });

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  bool _isOnline = ConnectivityService.instance.isOnline;
  late final StreamSubscription<bool> _sub;

  @override
  void initState() {
    super.initState();
    _sub = ConnectivityService.instance.onStatusChange.listen((online) {
      if (!mounted) return;
      final wasOffline = !_isOnline;
      setState(() => _isOnline = online);
      if (online && wasOffline) {
        widget.onReconnected?.call();
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isOnline)
          const Positioned.fill(child: _OfflineView()),
      ],
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 72, color: Colors.grey[350]),
          const SizedBox(height: 13),
          const Text(
            "You're offline",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "We'll reconnect automatically as soon as\nyour internet is back.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),


        ],
      ),
    );
  }
}