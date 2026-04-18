import 'package:flutter/material.dart';

class RefreshableScreen extends StatelessWidget {
  final Future<void> Function() onRefresh;

  final Widget child;

  final Color color;

  const RefreshableScreen({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color = const Color(0xFFE91E63),
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color,
      child: child,
    );
  }
}