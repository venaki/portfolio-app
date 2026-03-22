import { useState } from 'react';
import { View, Text, ScrollView, TouchableOpacity, StyleSheet } from 'react-native';
import { useApp } from '../../src/context/AppContext';
import { useResponsive } from '../../src/hooks/useResponsive';
import { COLORS } from '../../src/constants';
import { FilterTabs } from '../../src/components/FilterTabs';
import { HoldingCard } from '../../src/components/HoldingCard';
import { HoldingRow } from '../../src/components/HoldingRow';
import { AddTransactionModal } from '../../src/components/AddTransactionModal';
import { Owner } from '../../src/types';

const FILTER_OPTIONS = ['전체', '본석', '연지', '나은'];

export default function Portfolio() {
  const { holdings, settings, market } = useApp();
  const { isMobile, isPC } = useResponsive();

  const [selectedOwner, setSelectedOwner] = useState<string>('전체');
  const [showModal, setShowModal] = useState(false);

  const filteredHoldings = selectedOwner === '전체'
    ? holdings
    : holdings.filter((h) => h.owner === (selectedOwner as Owner));

  return (
    <View style={styles.container}>
      {/* Mobile layout */}
      {isMobile && (
        <>
          <View style={styles.headerMobile}>
            <Text style={styles.headerTitle}>포트폴리오</Text>
            <TouchableOpacity
              style={[styles.addBtnMobile, { backgroundColor: '#16A34A' }]}
              onPress={() => setShowModal(true)}
              activeOpacity={0.8}
            >
              <Text style={styles.addBtnText}>추가</Text>
            </TouchableOpacity>
          </View>

          <View style={styles.filterWrapperMobile}>
            <FilterTabs
              options={FILTER_OPTIONS}
              selected={selectedOwner}
              onSelect={setSelectedOwner}
            />
          </View>

          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.listContent}
            showsVerticalScrollIndicator={false}
          >
            {filteredHoldings.length === 0 ? (
              <View style={styles.emptyContainer}>
                <Text style={styles.emptyText}>보유 종목이 없습니다</Text>
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
            <Text style={styles.headerTitle}>포트폴리오</Text>
            <View style={styles.headerActions}>
              <FilterTabs
                options={FILTER_OPTIONS}
                selected={selectedOwner}
                onSelect={setSelectedOwner}
              />
              <TouchableOpacity
                style={[styles.addBtnPC, { backgroundColor: '#16A34A' }]}
                onPress={() => setShowModal(true)}
                activeOpacity={0.8}
              >
                <Text style={styles.addBtnText}>종목 추가</Text>
              </TouchableOpacity>
            </View>
          </View>

          {/* Table */}
          <View style={styles.tableContainer}>
            {/* Table header */}
            <View style={styles.tableHeader}>
              <Text style={[styles.colHeaderTicker]}>종목</Text>
              <Text style={[styles.colHeaderOwner]}>명의</Text>
              <Text style={[styles.colHeaderFill]}>현재가</Text>
              <Text style={[styles.colHeaderFill]}>수량</Text>
              <Text style={[styles.colHeaderFill]}>평가금액</Text>
              <Text style={[styles.colHeaderFill]}>수익률</Text>
            </View>

            <ScrollView showsVerticalScrollIndicator={false}>
              {filteredHoldings.length === 0 ? (
                <View style={styles.emptyContainer}>
                  <Text style={styles.emptyText}>보유 종목이 없습니다</Text>
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

      <AddTransactionModal visible={showModal} onClose={() => setShowModal(false)} />
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
  headerTitle: {
    fontFamily: 'Newsreader_500Medium',
    fontSize: 22,
    color: COLORS.textPrimary,
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
  addBtnText: {
    fontFamily: 'Inter_600SemiBold',
    fontSize: 13,
    color: '#FFFFFF',
  },
  filterWrapperMobile: {
    paddingHorizontal: 16,
    marginBottom: 12,
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
  emptyContainer: {
    paddingVertical: 48,
    alignItems: 'center',
  },
  emptyText: {
    fontFamily: 'Inter_400Regular',
    fontSize: 14,
    color: COLORS.textTertiary,
  },
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
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  colHeaderOwner: {
    width: 70,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    color: COLORS.textSecondary,
  },
  colHeaderFill: {
    flex: 1,
    fontFamily: 'Inter_600SemiBold',
    fontSize: 12,
    color: COLORS.textSecondary,
    textAlign: 'right',
  },
});
