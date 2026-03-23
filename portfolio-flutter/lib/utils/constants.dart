import 'package:flutter/material.dart';

class AccentPreset {
  final String name;
  final Color color;
  const AccentPreset(this.name, this.color);
}

const accentPresets = [
  AccentPreset('Teal', Color(0xFF0D6E6E)),
  AccentPreset('Blue', Color(0xFF2563EB)),
  AccentPreset('Purple', Color(0xFF7C3AED)),
  AccentPreset('Green', Color(0xFF16A34A)),
  AccentPreset('Orange', Color(0xFFEA580C)),
  AccentPreset('Rose', Color(0xFFE11D48)),
];

const accountColors = [
  Color(0xFF0D6E6E),
  Color(0xFFE07B54),
  Color(0xFF5B7FD6),
  Color(0xFF9333EA),
  Color(0xFFDC2626),
  Color(0xFFCA8A04),
];

Color getAccountColor(int index) => accountColors[index % accountColors.length];

const positiveColor = Color(0xFF16A34A);
const negativeColor = Color(0xFFE07B54);

const fallbackExchangeRate = 1450.0;

const corsProxyBase = 'https://portfolio-cors-proxy.venaki.workers.dev';

const defaultAccentColorHex = '#0D6E6E';

Color hexToColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 7) buffer.write('FF');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}
