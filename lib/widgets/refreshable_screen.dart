import 'package:flutter/material.dart';
import '../config/app_color.dart';

class RefreshableScreen extends StatelessWidget {
  final Future<void> Function() onRefresh;

  final Widget child;

  final Color color;

  const RefreshableScreen({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color = AppColors.primaryBlue,
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