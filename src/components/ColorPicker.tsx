import { View, Text, Pressable, StyleSheet } from 'react-native';
import { COLORS } from '../constants';

interface ColorOption {
  name: string;
  color: string;
}

interface ColorPickerProps {
  colors: readonly ColorOption[];
  selected: string;
  onSelect: (color: string) => void;
}

export function ColorPicker({ colors, selected, onSelect }: ColorPickerProps) {
  return (
    <View style={styles.row}>
      {colors.map((item) => {
        const isSelected = item.color === selected;
        return (
          <Pressable
            key={item.color}
            onPress={() => onSelect(item.color)}
            style={[
              styles.swatch,
              { backgroundColor: item.color },
              isSelected && { borderWidth: 3, borderColor: item.color },
            ]}
            accessibilityLabel={item.name}
            accessibilityState={{ selected: isSelected }}
          >
            {isSelected && (
              <Text style={styles.check}>✓</Text>
            )}
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: 12,
    flexWrap: 'wrap',
  },
  swatch: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
  check: {
    color: COLORS.white,
    fontSize: 14,
    fontFamily: 'Inter_600SemiBold',
    lineHeight: 16,
  },
});
