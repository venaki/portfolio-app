import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';

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
    backgroundColor: '#F0F0F0',
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
    backgroundColor: '#FFFFFF',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  label: {
    fontSize: 13,
  },
  labelSelected: {
    fontFamily: 'Inter_600SemiBold',
    color: '#1A1A1A',
  },
  labelUnselected: {
    fontFamily: 'Inter_500Medium',
    color: '#888888',
  },
});
