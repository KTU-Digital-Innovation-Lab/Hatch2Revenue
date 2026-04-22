import 'package:flutter/material.dart';

class TractorIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const TractorIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/chicken_tractor.png',
      width: size,
      height: size,
      color: color,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to agriculture icon if image fails to load
        return Icon(Icons.agriculture, size: size, color: color);
      },
    );
  }
}
