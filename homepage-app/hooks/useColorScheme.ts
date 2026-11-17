import { useColorScheme as useRNColorScheme } from 'react-native';

/**
 * React Native's ColorSchemeName also includes 'unspecified' and null. The app's
 * themes only define 'light' and 'dark', so fall back to 'light' for anything else.
 */
export function useColorScheme(): 'light' | 'dark' {
  return useRNColorScheme() === 'dark' ? 'dark' : 'light';
}
