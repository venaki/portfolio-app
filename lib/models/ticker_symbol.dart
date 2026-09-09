/// KRX short codes contain six digits and/or uppercase Latin letters.
/// Examples: 005930 (ordinary shares), 00088K (preferred shares), 0195R0 (ETF).
bool isKoreanTicker(String ticker) => RegExp(r'^[0-9A-Z]{6}$').hasMatch(ticker);

/// Restore leading zeroes only when Sheets converted a numeric code to a number.
/// Alphanumeric codes already have a meaningful, fixed-width representation.
String normalizeTicker(String value, {required bool isKorean}) {
  final ticker = value.trim().toUpperCase();
  return isKorean && RegExp(r'^\d{1,5}$').hasMatch(ticker)
      ? ticker.padLeft(6, '0')
      : ticker;
}
