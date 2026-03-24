import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Portfolio 화면 필터
final portfolioAccountFilter = StateProvider<String>((ref) => '전체');
final portfolioMarketFilter = StateProvider<String>((ref) => '전체');

/// History 화면 필터
final historyMarketFilter = StateProvider<String>((ref) => '전체');
final historyAccountFilter = StateProvider<String>((ref) => '전체');
final historyTypeFilter = StateProvider<String>((ref) => '전체');
final historyBrokerFilter = StateProvider<String>((ref) => '전체');
final historyFilterExpanded = StateProvider<bool>((ref) => false);

/// Assets 화면 필터
final assetsAccountFilter = StateProvider<String>((ref) => '전체');
