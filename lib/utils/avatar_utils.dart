import 'package:flutter/material.dart';

class AvatarUtils {
  const AvatarUtils._();

  static Color colorFromHex(String value) {
    final hex = value.replaceAll('#', '').trim();
    final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return Color(parsed ?? 0xFF2563EB);
  }

  static const colorChoices = [
    '#2563EB',
    '#059669',
    '#DC2626',
    '#7C3AED',
    '#EA580C',
    '#0891B2',
    '#4F46E5',
    '#BE123C',
  ];
}
