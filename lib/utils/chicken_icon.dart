import 'package:flutter/material.dart';

class ChickenIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const ChickenIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/chicken.png',
      width: size,
      height: size,
      color: color,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to a bird icon if image fails to load
        return Icon(Icons.flutter_dash, size: size, color: color);
      },
    );
  }
}
