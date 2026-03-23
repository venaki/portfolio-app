import '../models/holding.dart';
import '../models/transaction.dart';

double calcProfitUSD(Holding holding, double currentPrice) {
  return (currentPrice - holding.avgCost) * holding.shares;
}

double calcProfitPercentUSD(Holding holding, double currentPrice) {
  if (holding.avgCost == 0) return 0;
  return ((currentPrice - holding.avgCost) / holding.avgCost) * 100;
}

double calcTotalValueKRW(Holding holding, double currentPrice, double currentRate) {
  if (holding.currency == Currency.krw) return currentPrice * holding.shares;
  return currentPrice * holding.shares * currentRate;
}

double calcCostKRW(Holding holding) {
  if (holding.currency == Currency.krw) return holding.avgCost * holding.shares;
  return holding.avgCost * holding.shares * holding.avgExchangeRate;
}

double calcProfitKRW(Holding holding, double currentPrice, double currentRate) {
  return calcTotalValueKRW(holding, currentPrice, currentRate) - calcCostKRW(holding);
}

double calcProfitPercentKRW(Holding holding, double currentPrice, double currentRate) {
  final cost = calcCostKRW(holding);
  if (cost == 0) return 0;
  return ((calcTotalValueKRW(holding, currentPrice, currentRate) - cost) / cost) * 100;
}

double calcDailyChangeKRW(Holding holding, double currentPrice, double closeYest, double currentRate) {
  if (holding.currency == Currency.krw) return (currentPrice - closeYest) * holding.shares;
  return (currentPrice - closeYest) * holding.shares * currentRate;
}

({double usd, double krw}) calcRealizedPL(double sellShares, double sellPrice, double sellRate, double avgCost, double avgRate) {
  return (
    usd: (sellPrice - avgCost) * sellShares,
    krw: sellPrice * sellShares * sellRate - avgCost * sellShares * avgRate,
  );
}
