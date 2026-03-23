import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { COLORS } from '../constants';

interface FilterTabsProps {
  options: string[];
  selected: string;
  onSelect: (value: string) => void;
}

export function FilterTabs({ options, selected, onSelect }: FilterTabsProps) {
  return (
    <View style={styles.container}>
      {options.map((option) => {
        const isSelected = option === selected;
        return (
          <TouchableOpacity
            key={option}
            style={[styles.tab, isSelected && styles.tabSelected]}
            onPress={() => onSelect(option)}
            activeOpacity={0.7}
          >
            <Text style={[styles.label, isSelected ? styles.labelSelected : styles.labelUnselected]}>
              {option}
            </Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    backgroundColor: COLORS.muted,
    borderRadius: 8,
    padding: 4,
  },
  tab: {
    flex: 1,
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: 6,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabSelected: {
    backgroundColor: COLORS.card,
    boxShadow: '0px 1px 2px rgba(0, 0, 0, 0.1)',
  },
  label: {
    fontSize: 13,
  },
  labelSelected: {
    fontWeight: '600',
    color: COLORS.textPrimary,
  },
  labelUnselected: {
    fontWeight: '500',
    color: COLORS.textTertiary,
  },
});
