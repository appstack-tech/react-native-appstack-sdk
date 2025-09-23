import { Image } from 'expo-image';
import { Platform, StyleSheet, Alert, TouchableOpacity } from 'react-native';
import { useEffect, useState } from 'react';

import { HelloWave } from '@/components/HelloWave';
import ParallaxScrollView from '@/components/ParallaxScrollView';
import { ThemedText } from '@/components/ThemedText';
import { ThemedView } from '@/components/ThemedView';
import AppstackSDK from 'react-native-appstack-sdk';
import { EventType } from 'react-native-appstack-sdk';

export default function HomeScreen() {
  const [isSDKInitialized, setIsSDKInitialized] = useState(false);
  const [sdkError, setSdkError] = useState<string | null>(null);

  // Initialize SDK when component mounts
  useEffect(() => {
    initializeAppstackSDK();
  }, []);

  const initializeAppstackSDK = async () => {
    try {
      console.log('Initializing Appstack SDK...');
      
      // Debug: Check what's available in NativeModules
      // eslint-disable-next-line @typescript-eslint/no-require-imports
      const { NativeModules } = require('react-native');
      console.log('Available native modules:', Object.keys(NativeModules));
      console.log('AppstackReactNative module:', NativeModules.AppstackReactNative);
      console.log('Is AppstackReactNative available:', !!NativeModules.AppstackReactNative);

      // Read API key from environment
      // const apiKey = process.env.EXPO_PUBLIC_APPSTACK_API_KEY;
      let apiKey = 'h6i3g37nfk7qo42dgqsxpb4z';
      let endpointUrl = 'https://api.event.dev.appstack.tech/android/';

      if (Platform.OS === 'ios') {
        endpointUrl = 'https://api.event.dev.appstack.tech';
      }

      if (!apiKey || apiKey.trim() === '') {
        const msg = 'Missing EXPO_PUBLIC_APPSTACK_API_KEY. Set it in your env (e.g. eas.json env or .env) to initialize the SDK.';
        console.warn(msg);
        setSdkError(msg);
        setIsSDKInitialized(false);
        return;
      }

      // Configure the SDK with the provided key and all available parameters
      await AppstackSDK.configure(
        apiKey.trim(),
        true, // isDebug - enable debug mode for development
        endpointUrl, // endpointBaseUrl - custom endpoint
        0 // logLevel - 0=DEBUG, 1=INFO, 2=WARN, 3=ERROR
      );
      setIsSDKInitialized(true);
      setSdkError(null);

      console.log('Appstack SDK configured successfully');

      // Send a basic event to test
      await AppstackSDK.sendEvent(EventType.CUSTOM, 'APP_OPENED');
      console.log('APP_OPENED event sent successfully');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      console.error('Failed to initialize Appstack SDK:', error);
      setSdkError(errorMessage);

      // Only show alert if it's not the common linking error
      if (!errorMessage.includes("doesn't seem to be linked")) {
        Alert.alert('SDK Error', `Failed to initialize Appstack SDK: ${errorMessage}`);
      }
    }
  };

  const handleTestEvent = async () => {
    if (!isSDKInitialized) {
      Alert.alert('SDK not initialized', 'Please wait for SDK to initialize');
      return;
    }

    try {
      await AppstackSDK.sendEvent(EventType.CUSTOM, 'TEST_BUTTON_PRESSED');
      Alert.alert('Success!', 'Test event sent successfully');
      console.log('TEST_BUTTON_PRESSED event sent successfully');
    } catch (error) {
      console.error('Failed to send event:', error);
      Alert.alert('Error', 'Failed to send test event');
    }
  };

  const handleRevenueEvent = async () => {
    if (!isSDKInitialized) {
      Alert.alert('SDK not initialized', 'Please wait for SDK to initialize');
      return;
    }

    try {
      await AppstackSDK.sendEvent(EventType.PURCHASE, "PURCHASE", 29.99);
      Alert.alert('Success!', 'Revenue event sent successfully');
      console.log('PURCHASE event with revenue sent successfully');
    } catch (error) {
      console.error('Failed to send revenue event:', error);
      Alert.alert('Error', 'Failed to send revenue event');
    }
  };

  const handleEventWithoutRevenue = async () => {
    if (!isSDKInitialized) {
      Alert.alert('SDK not initialized', 'Please wait for SDK to initialize');
      return;
    }

    try {
      await AppstackSDK.sendEvent(EventType.CUSTOM, 'SIGN_UP'); // No revenue parameter
      Alert.alert('Success!', 'Sign up event sent successfully');
      console.log('SIGN_UP event sent successfully');
    } catch (error) {
      console.error('Failed to send sign up event:', error);
      Alert.alert('Error', 'Failed to send sign up event');
    }
  };

  const handleCustomEvent = async () => {
    if (!isSDKInitialized) {
      Alert.alert('SDK not initialized', 'Please wait for SDK to initialize');
      return;
    }

    try {
      await AppstackSDK.sendEvent(EventType.CUSTOM, 'CUSTOM_EVENT_NAME', 15.50);
      Alert.alert('Success!', 'Custom event sent successfully');
      console.log('CUSTOM_EVENT_NAME event sent successfully');
    } catch (error) {
      console.error('Failed to send custom event:', error);
      Alert.alert('Error', 'Failed to send custom event');
    }
  };

  const reinitializeWithBasicConfig = async () => {
    try {
      console.log('Reinitializing with basic configuration...');
      
      let apiKey = 'your-appstack-api-key';
      if (Platform.OS === 'ios') {
        apiKey = 'your-appstack-api-key';
      }

      // Basic configuration (backward compatible)
      await AppstackSDK.configure(apiKey.trim());
      
      setIsSDKInitialized(true);
      setSdkError(null);
      Alert.alert('Success!', 'SDK reinitialized with basic configuration');
      console.log('Appstack SDK reinitialized with basic configuration');
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      console.error('Failed to reinitialize Appstack SDK:', error);
      setSdkError(errorMessage);
      Alert.alert('Error', `Failed to reinitialize SDK: ${errorMessage}`);
    }
  };

  return (
    <ParallaxScrollView
      headerBackgroundColor={{ light: '#A1CEDC', dark: '#1D3D47' }}
      headerImage={
        <Image
          source={require('@/assets/images/partial-react-logo.png')}
          style={styles.reactLogo}
        />
      }>
      <ThemedView style={styles.titleContainer}>
        <ThemedText type="title">Welcome!</ThemedText>
        <HelloWave />
      </ThemedView>
      
      {/* SDK Status */}
      <ThemedView style={styles.stepContainer}>
        <ThemedText type="subtitle">Appstack SDK Status</ThemedText>
        <ThemedText style={{ color: isSDKInitialized ? 'green' : 'red' }}>
          {isSDKInitialized ? '✅ SDK Initialized' : '⏳ Initializing SDK...'}
        </ThemedText>
        {sdkError && (
          <ThemedText style={{ color: 'red', marginTop: 4 }}>{sdkError}</ThemedText>
        )}
      </ThemedView>

      {/* Configuration Tests */}
      <ThemedView style={styles.stepContainer}>
        <ThemedText type="subtitle">Configuration Options</ThemedText>
        <ThemedText style={styles.infoText}>
          Current: Full configuration with debug mode, custom endpoint, and DEBUG log level
        </ThemedText>
        <TouchableOpacity style={styles.secondaryButton} onPress={reinitializeWithBasicConfig}>
          <ThemedText style={styles.buttonText}>Test Basic Configuration</ThemedText>
        </TouchableOpacity>
      </ThemedView>

      {/* Event Tests */}
      <ThemedView style={styles.stepContainer}>
        <ThemedText type="subtitle">Event Testing</ThemedText>
        <TouchableOpacity style={styles.button} onPress={handleTestEvent}>
          <ThemedText style={styles.buttonText}>Send Test Event</ThemedText>
        </TouchableOpacity>
        <TouchableOpacity style={styles.button} onPress={handleEventWithoutRevenue}>
          <ThemedText style={styles.buttonText}>Send Event (No Revenue)</ThemedText>
        </TouchableOpacity>
        <TouchableOpacity style={styles.button} onPress={handleRevenueEvent}>
          <ThemedText style={styles.buttonText}>Send Revenue Event ($29.99)</ThemedText>
        </TouchableOpacity>
        <TouchableOpacity style={styles.button} onPress={handleCustomEvent}>
          <ThemedText style={styles.buttonText}>Send Custom Event ($15.50)</ThemedText>
        </TouchableOpacity>
      </ThemedView>

      <ThemedView style={styles.stepContainer}>
        <ThemedText type="subtitle">Step 1: Try it</ThemedText>
        <ThemedText>
          Edit <ThemedText type="defaultSemiBold">app/(tabs)/index.tsx</ThemedText> to see changes.
          Press{' '}
          <ThemedText type="defaultSemiBold">
            {Platform.select({
              ios: 'cmd + d',
              android: 'cmd + m', 
              web: 'F12',
            })}
          </ThemedText>{' '}
          to open developer tools.
        </ThemedText>
      </ThemedView>
      <ThemedView style={styles.stepContainer}>
        <ThemedText type="subtitle">Step 2: Explore</ThemedText>
        <ThemedText>
          {`Tap the Explore tab to learn more about what's included in this starter app.`}
        </ThemedText>
      </ThemedView>
      <ThemedView style={styles.stepContainer}>
        <ThemedText type="subtitle">Step 3: Get a fresh start</ThemedText>
        <ThemedText>
          {`When you're ready, run `}
          <ThemedText type="defaultSemiBold">npm run reset-project</ThemedText> to get a fresh{' '}
          <ThemedText type="defaultSemiBold">app</ThemedText> directory. This will move the current{' '}
          <ThemedText type="defaultSemiBold">app</ThemedText> to{' '}
          <ThemedText type="defaultSemiBold">app-example</ThemedText>.
        </ThemedText>
      </ThemedView>
    </ParallaxScrollView>
  );
}

const styles = StyleSheet.create({
  titleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  stepContainer: {
    gap: 8,
    marginBottom: 8,
  },
  reactLogo: {
    height: 178,
    width: 290,
    bottom: 0,
    left: 0,
    position: 'absolute',
  },
  button: {
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginVertical: 4,
  },
  secondaryButton: {
    backgroundColor: '#34C759',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginVertical: 4,
  },
  buttonText: {
    color: 'white',
    fontWeight: '600',
  },
  infoText: {
    fontSize: 12,
    opacity: 0.7,
    marginBottom: 8,
  },
});
