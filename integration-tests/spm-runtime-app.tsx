import React, { useEffect, useState } from 'react';
import { Platform, Text, View } from 'react-native';
import AppstackSDK, { EventType } from 'react-native-appstack-sdk';

const RESULT_PREFIX = 'APPSTACK_RUNTIME_RESULT:';
const FAILURE_PREFIX = 'APPSTACK_RUNTIME_FAIL:';
const RESULT_URL = '__APPSTACK_RUNTIME_RESULT_URL__';
const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function reportResult(kind, payload) {
  const response = await fetch(RESULT_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ kind, payload }),
  });
  if (!response.ok) {
    throw new Error(`runtime recorder rejected result with HTTP ${response.status}`);
  }
}

async function waitForAttribution() {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const value = await AppstackSDK.getAttributionParams();
    if (value && value.runtime_validation === 'attributed' && value.unicode === 'café 🚀') {
      return value;
    }
    await delay(500);
  }
  throw new Error('attribution parameters did not arrive from the recording backend');
}

export default function App() {
  const [status, setStatus] = useState('APPSTACK_RUNTIME_RUNNING');

  useEffect(() => {
    (async () => {
      try {
        const configured = await AppstackSDK.configure('runtime-validation-local-key', {
          logLevel: 0,
          customerUserId: 'runtime-validation-user',
        });
        const attribution = await waitForAttribution();
        const callbackResults = await Promise.all([
          AppstackSDK.getAttributionParams(),
          AppstackSDK.getAttributionParams(),
          AppstackSDK.getAttributionParams(),
        ]);
        const validCallbacks = callbackResults.filter(
          (value) =>
            value && value.runtime_validation === 'attributed' && value.unicode === 'café 🚀'
        ).length;

        await AppstackSDK.sendEvent('runtime_validation_custom', {
          string: 'bridge-value',
          number: 42,
          decimal: 9.75,
          boolean: true,
          unicode: 'café 🚀',
          array: ['one', 2, false],
          nested: { enabled: true, items: ['nested', 3, false] },
        });
        await AppstackSDK.sendEvent(EventType.LOGIN, { state: 'ready', sequence: 2 });

        let validationError = '';
        try {
          await AppstackSDK.sendEvent();
        } catch (error) {
          validationError = error && error.message ? error.message : String(error);
        }

        let legacyCallRejected = false;
        try {
          await AppstackSDK.sendEvent('PURCHASE', null, { revenue: 1.5 });
        } catch (error) {
          legacyCallRejected = /removed in 3\.0/.test(
            error && error.message ? error.message : String(error)
          );
        }

        await AppstackSDK.sendEvent('runtime_validation_bare');

        // Native event delivery is fire-and-forget.
        await delay(4000);
        const appstackId = await AppstackSDK.getAppstackId();
        const sdkDisabled = await AppstackSDK.isSdkDisabled();
        const uuidRe =
          /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
        const result = {
          platform: Platform.OS,
          configured: configured === true,
          appstackIdPresent: uuidRe.test(String(appstackId || '')),
          sdkDisabled,
          callbackCount: callbackResults.length,
          successCount: validCallbacks,
          attributionValidated:
            attribution.runtime_validation === 'attributed' && attribution.unicode === 'café 🚀',
          validationError,
          legacyCallRejected,
          errors: [],
        };
        await reportResult('success', result);
        console.log(RESULT_PREFIX + JSON.stringify(result));
        setStatus('APPSTACK_RUNTIME_OK');
      } catch (error) {
        const message = error && error.message ? error.message : String(error);
        try {
          await reportResult('failure', { message });
        } catch (reportError) {
          console.error(FAILURE_PREFIX + `could not report "${message}": ${String(reportError)}`);
        }
        console.error(FAILURE_PREFIX + message);
        setStatus('APPSTACK_RUNTIME_FAIL');
      }
    })();
  }, []);

  return (
    <View>
      <Text>{status}</Text>
    </View>
  );
}
