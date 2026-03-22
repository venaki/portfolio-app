import { useWindowDimensions } from 'react-native';

const BREAKPOINT = 768;

export function useResponsive() {
  const { width } = useWindowDimensions();
  return {
    isMobile: width < BREAKPOINT,
    isPC: width >= BREAKPOINT,
    width,
  };
}
