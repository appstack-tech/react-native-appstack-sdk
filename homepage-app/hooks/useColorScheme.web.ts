import { useSyncExternalStore } from 'react';
import { useColorScheme as useRNColorScheme } from 'react-native';

const subscribe = () => () => {};

/**
 * To support static rendering, this value needs to be re-calculated on the client side for web.
 * The server snapshot is false, so static HTML always renders the light theme.
 */
export function useColorScheme(): 'light' | 'dark' {
  const isClient = useSyncExternalStore(
    subscribe,
    () => true,
    () => false
  );
  const colorScheme = useRNColorScheme();

  return isClient && colorScheme === 'dark' ? 'dark' : 'light';
}
