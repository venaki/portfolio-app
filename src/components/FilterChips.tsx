import { View, Text, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';

interface FilterChipsProps {
  options: { label: string; value: string }[];
  selected: string;
  onSelect: (value: string) => void;
  accentColor: string;
}

export function FilterChips({ options, selected, onSelect, accentColor }: FilterChipsProps) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.container}
    >
      {options.map((option) => {
        const isSelected = option.value === selected;
        return (
          <TouchableOpacity
            key={option.value}
            style={[
              styles.chip,
              isSelected
                ? { backgroundColor: accentColor }
                : styles.chipUnselected,
            ]}
            onPress={() => onSelect(option.value)}
            activeOpacity={0.7}
          >
            <Text
              style={[
                styles.label,
                isSelected ? styles.labelSelected : styles.labelUnselected,
              ]}
            >
              {option.label}
            </Text>
          </TouchableOpacity>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 16,
  },
  chip: {
    paddingVertical: 6,
    paddingHorizontal: 14,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  chipUnselected: {
    backgroundColor: '#F0F0F0',
  },
  label: {
    fontSize: 13,
  },
  labelSelected: {
    fontFamily: 'Inter_600SemiBold',
    color: '#FFFFFF',
  },
  labelUnselected: {
    fontFamily: 'Inter_500Medium',
    color: '#888888',
  },
});
