// lib/utils/color_utils.dart
import 'package:flutter/material.dart';

Color textColorForBackground(Color background) {
  return background.computeLuminance() > 0.4
      ? const Color(0xFF1A1A1A)
      : Colors.white;
}

Color textColorForGradient(Color start, Color end) {
  final blended = Color.lerp(start, end, 0.5)!;
  return textColorForBackground(blended);
}