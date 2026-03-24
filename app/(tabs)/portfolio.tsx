import { useState } from 'react';
import { View, Text, ScrollView, TouchableOpacity, RefreshControl, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { COLORS, ASSET_CLASS_OPTIONS, ASSET_CLASS_LABELS } from '../../src/constants';
import { PAGE } from '../../src/styles/shared';
import { FilterTabs } from '../../src/components/FilterTabs';
import { HoldingCard } from '../../src/components/HoldingCard';
import { HoldingRow } from '../../src/components/HoldingRow';
import { Owner } from '../../src/types';

export default function Portfolio() {
  const { holdings, settings, market, accounts } = useApp();
  const OWNER_OPTIONS = ['전체', ...accounts];
  const { isMobile, isPC } = useResponsive();

  const [selectedAssetClass, setSelectedAssetClass] = useState<string>('전체');
  const [selectedOwner, setSelectedOwner] = useState<string>('전체');


  const filteredHoldings = holdings.filter((h) => {
    // Asset class filter
    const acFilter = ASSET_CLASS_LABELS[selectedAssetClass];
    if (acFilter !== 'all' && h.assetClass !== acFilter) return false;
    // Owner filter
    if (selectedOwner !== '전체' && h.owner !== (selectedOwner as Owner)) return false;
    return true;
  });

  return (
    <View style={styles.container}>
      {/* Mobile layout */}
      {isMobile && (
        <>
          <View style={styles.headerMobile}>
            <Text style={PAGE.title}>포트폴리오</Text>
          </View>

          <View style={styles.filterWrapperMobile}>
            <FilterTabs
              options={OWNER_OPTIONS}
              selected={selectedOwner}
              onSelect={setSelectedOwner}
            />
          </View>
          <View style={styles.filterWrapperMobile}>
            <FilterTabs
              options={ASSET_CLASS_OPTIONS}
              selected={selectedAssetClass}
              onSelect={setSelectedAssetClass}
            />
          </View>

          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.listContent}
            showsVerticalScrollIndicator={false}
            refreshControl={
              <RefreshControl
                refreshing={market.isLoading}
                onRefresh={market.refresh}
                tintColor={settings.accentColor}
              />
            }
          >
            {filteredHoldings.length === 0 ? (
              <View style={PAGE.emptyContainer}>
                <Text style={PAGE.emptyText}>보유 종목이 없습니다</Text>
              </View>
            ) : (
              filteredHoldings.map((holding) => (
                <View key={`${holding.owner}-${holding.ticker}`} style={styles.cardWrapper}>
                  <HoldingCard
                    holding={holding}
                    quote={market.quotes[holding.ticker]}
                    exchangeRate={market.exchangeRate}
                    accentColor={settings.accentColor}
                  />
                </View>
              ))
            )}
          </ScrollView>
        </>
      )}

      {/* PC layout */}
      {isPC && (
        <>
          <View style={styles.headerPC}>
            <Text style={PAGE.title}>포트폴리오</Text>
            <View style={styles.headerActions}>
              <FilterTabs
                options={OWNER_OPTIONS}
                selected={selectedOwner}
                onSelect={setSelectedOwner}
              />
              <View style={{ width: 8 }} />
              <FilterTabs
                options={ASSET_CLASS_OPTIONS}
                selected={selectedAssetClass}
                onSelect={setSelectedAssetClass}
              />
            </View>
          </View>

          {/* Table */}
          <View style={styles.tableContainer}>
            {/* Table header */}
            <View style={styles.tableHeader}>
              <Text style={[styles.colHeaderTicker]}>종목</Text>
              <Text style={[styles.colHeaderFill]}>현재가</Text>
              <Text style={[styles.colHeaderFill]}>수익</Text>
              <Text style={[styles.colHeaderFill]}>평단가</Text>
              <Text style={[styles.colHeaderFill]}>수량</Text>
              <Text style={[styles.colHeaderFill]}>평가금액</Text>
              <Text style={[styles.colHeaderFill]}>매입환율</Text>
            </View>

            <ScrollView
              showsVerticalScrollIndicator={false}
              refreshControl={
                <RefreshControl
                  refreshing={market.isLoading}
                  onRefresh={market.refresh}
                  tintColor={settings.accentColor}
                />
              }
            >
              {filteredHoldings.length === 0 ? (
                <View style={PAGE.emptyContainer}>
                  <Text style={PAGE.emptyText}>보유 종목이 없습니다</Text>
                </View>
              ) : (
                filteredHoldings.map((holding) => (
                  <HoldingRow
                    key={`${holding.owner}-${holding.ticker}`}
                    holding={holding}
                    quote={market.quotes[holding.ticker]}
                    exchangeRate={market.exchangeRate}
                    accentColor={settings.accentColor}
                  />
                ))
              )}
            </ScrollView>
          </View>
        </>
      )}

    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background,
  },
  headerMobile: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: 20,
    paddingBottom: 8,
  },
  addBtnMobile: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 8,
  },
  addBtnPC: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
    marginLeft: 12,
  },
  filterWrapperMobile: {
    paddingHorizontal: 16,
    marginBottom: 8,
  },
  scrollView: {
    flex: 1,
  },
  listContent: {
    paddingHorizontal: 16,
    paddingBottom: 100,
    gap: 10,
  },
  cardWrapper: {},
  headerPC: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingTop: 24,
    paddingBottom: 16,
  },
  headerActions: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  tableContainer: {
    flex: 1,
    marginHorizontal: 24,
    backgroundColor: COLORS.card,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: COLORS.border,
    overflow: 'hidden',
  },
  tableHeader: {
    flexDirection: 'row',
    backgroundColor: COLORS.muted,
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border,
  },
  colHeaderTicker: {
    width: 160,
    fontWeight: '600',
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  colHeaderFill: {
    flex: 1,
    fontWeight: '600',
    fontSize: 12,
    color: COLORS.textSecondary,
    textAlign: 'right',
  },
});
