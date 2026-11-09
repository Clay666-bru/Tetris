import 'package:flutter/material.dart';

class Pixel extends StatelessWidget {
  final Color color;

  const Pixel({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3), // Bordes ligeramente suavizados
        border: Border.all(
          color: Colors.black, // Crea la separación de rejilla retro
          width: 0.8,
        ),
      ),
    );
  }
}
