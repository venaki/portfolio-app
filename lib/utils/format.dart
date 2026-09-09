import 'package:intl/intl.dart';

final _krwFormat = NumberFormat('#,###', 'ko_KR');
final _usdFormat = NumberFormat('#,##0.00', 'en_US');
final _sharesFormat = NumberFormat('#,##0.########', 'ko_KR');

String formatKRW(double value) {
  if (!value.isFinite) return '—';
  final abs = value.abs().truncate();
  final formatted = _krwFormat.format(abs);
  return value < 0 ? '-₩$formatted' : '₩$formatted';
}

String formatUSD(double value) {
  if (!value.isFinite) return '—';
  final abs = value.abs();
  final formatted = _usdFormat.format(abs);
  return value < 0 ? '-\$$formatted' : '\$$formatted';
}

String formatPercent(double value) {
  if (!value.isFinite) return '—';
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String formatShares(double value) {
  if (!value.isFinite) return '—';
  if (value != 0 && value.abs() < 0.00000001) return value.toString();
  return _sharesFormat.format(value);
}

String formatDate(String isoString) {
  return isoString.length >= 10 ? isoString.substring(0, 10) : isoString;
}

String formatRelativeTime(String isoString) {
  final parsed = DateTime.tryParse(isoString);
  if (parsed == null) return '시간 확인 불가';
  final diff = DateTime.now().difference(parsed);
  final minutes = diff.inMinutes;
  if (minutes < 1) return '방금 전';
  if (minutes < 60) return '$minutes분 전';
  final hours = diff.inHours;
  if (hours < 24) return '$hours시간 전';
  return '${diff.inDays}일 전';
}
