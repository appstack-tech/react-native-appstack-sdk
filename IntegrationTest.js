/**
 * Integration Test for React Native Appstack SDK
 * 
 * This file can be used to test that the Android integration works properly.
 * Copy this into a React Native app that has the SDK installed to test.
 */

import React, { useEffect, useState } from 'react';
import { View, Text, Button, Alert, ScrollView, StyleSheet } from 'react-native';
import AppstackSDK from 'react-native-appstack-sdk';

const IntegrationTest = () => {
  const [isConfigured, setIsConfigured] = useState(false);
  const [logs, setLogs] = useState([]);

  const addLog = (message, isError = false) => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [...prev, { message: `[${timestamp}] ${message}`, isError }]);
    console.log(message);
  };

  const testConfigure = async () => {
    try {
      addLog('Configuring SDK with API key...');
      const result = await AppstackSDK.configure('test-api-key-12345');
      addLog(`✅ Configure result: ${result}`);
      setIsConfigured(true);
    } catch (error) {
      addLog(`❌ Configure failed: ${error.message}`, true);
    }
  };

  const testSendEvent = async () => {
    try {
      addLog('Sending basic event...');
      const result = await AppstackSDK.sendEvent('PURCHASE');
      addLog(`✅ Send event result: ${result}`);
    } catch (error) {
      addLog(`❌ Send event failed: ${error.message}`, true);
    }
  };

  const testSendEventWithRevenue = async () => {
    try {
      addLog('Sending event with revenue...');
      const result = await AppstackSDK.sendEventWithRevenue('PURCHASE', 29.99);
      addLog(`✅ Send event with revenue result: ${result}`);
    } catch (error) {
      addLog(`❌ Send event with revenue failed: ${error.message}`, true);
    }
  };

  const testCustomEvent = async () => {
    try {
      addLog('Sending custom event...');
      const result = await AppstackSDK.sendEvent('MY_CUSTOM_EVENT');
      addLog(`✅ Custom event result: ${result}`);
    } catch (error) {
      addLog(`❌ Custom event failed: ${error.message}`, true);
    }
  };

  const testASAAttribution = async () => {
    try {
      addLog('Testing ASA Attribution...');
      const result = await AppstackSDK.enableASAAttribution();
      addLog(`✅ ASA Attribution result: ${result} (false expected on Android)`);
    } catch (error) {
      addLog(`❌ ASA Attribution failed: ${error.message}`, true);
    }
  };

  const testErrorHandling = async () => {
    try {
      addLog('Testing error handling with invalid API key...');
      await AppstackSDK.configure('');
    } catch (error) {
      addLog(`✅ Error handling works: ${error.message} (expected error)`);
    }

    try {
      addLog('Testing error handling with invalid event name...');
      await AppstackSDK.sendEvent('');
    } catch (error) {
      addLog(`✅ Error handling works: ${error.message} (expected error)`);
    }
  };

  const runAllTests = async () => {
    setLogs([]);
    addLog('🚀 Starting integration tests...');
    
    await testConfigure();
    await new Promise(resolve => setTimeout(resolve, 500));
    
    await testSendEvent();
    await new Promise(resolve => setTimeout(resolve, 500));
    
    await testSendEventWithRevenue();
    await new Promise(resolve => setTimeout(resolve, 500));
    
    await testCustomEvent();
    await new Promise(resolve => setTimeout(resolve, 500));
    
    await testASAAttribution();
    await new Promise(resolve => setTimeout(resolve, 500));
    
    await testErrorHandling();
    
    addLog('🎉 Integration tests completed!');
  };

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.title}>Appstack SDK Integration Test</Text>
      
      <View style={styles.buttonContainer}>
        <Button title="Run All Tests" onPress={runAllTests} />
      </View>

      <View style={styles.buttonContainer}>
        <Button title="Configure SDK" onPress={testConfigure} />
        <Button 
          title="Send Event" 
          onPress={testSendEvent} 
          disabled={!isConfigured}
        />
        <Button 
          title="Event + Revenue" 
          onPress={testSendEventWithRevenue}
          disabled={!isConfigured}
        />
        <Button 
          title="Custom Event" 
          onPress={testCustomEvent}
          disabled={!isConfigured}
        />
        <Button title="ASA Attribution" onPress={testASAAttribution} />
        <Button title="Error Handling" onPress={testErrorHandling} />
      </View>

      <View style={styles.logContainer}>
        <Text style={styles.logTitle}>Logs:</Text>
        {logs.map((log, index) => (
          <Text 
            key={index} 
            style={[styles.logText, log.isError && styles.errorText]}
          >
            {log.message}
          </Text>
        ))}
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
  },
  buttonContainer: {
    marginBottom: 20,
    gap: 10,
  },
  logContainer: {
    backgroundColor: '#fff',
    padding: 15,
    borderRadius: 8,
    minHeight: 200,
  },
  logTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 10,
  },
  logText: {
    fontSize: 12,
    marginBottom: 2,
    fontFamily: 'monospace',
  },
  errorText: {
    color: 'red',
  },
});

export default IntegrationTest;
