import { useEffect } from 'react';
import { Platform } from 'react-native';
import { Stack } from 'expo-router';
import { useFonts, Newsreader_400Regular, Newsreader_500Medium } from '@expo-google-fonts/newsreader';
import { JetBrainsMono_400Regular, JetBrainsMono_500Medium, JetBrainsMono_600SemiBold, JetBrainsMono_700Bold } from '@expo-google-fonts/jetbrains-mono';
import { Inter_400Regular, Inter_500Medium, Inter_600SemiBold } from '@expo-google-fonts/inter';
import * as SplashScreen from 'expo-splash-screen';
import { AppProvider } from '../src/context/AppContext';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  // Web: fonts loaded via CDN <link> in index.html, skip useFonts
  const isWeb = Platform.OS === 'web';
  const [fontsLoaded] = useFonts(isWeb ? {} : {
    Newsreader_400Regular,
    Newsreader_500Medium,
    JetBrainsMono_400Regular,
    JetBrainsMono_500Medium,
    JetBrainsMono_600SemiBold,
    JetBrainsMono_700Bold,
    Inter_400Regular,
    Inter_500Medium,
    Inter_600SemiBold,
  });

  useEffect(() => {
    if (fontsLoaded || isWeb) SplashScreen.hideAsync();
  }, [fontsLoaded, isWeb]);

  if (!fontsLoaded && !isWeb) return null;

  return (
    <AppProvider>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(tabs)" />
      </Stack>
    </AppProvider>
  );
}
