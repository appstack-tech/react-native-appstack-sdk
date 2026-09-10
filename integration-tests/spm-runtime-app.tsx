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
        // handleUniversalLink is documented as safe before configure() and as
        // performing no network request.
        const linkBeforeConfigure = await AppstackSDK.handleUniversalLink(
          'https://links.example.com/AbC123?screen=offer'
        );

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

        // Universal link marshalling across the bridge: a populated result, an
        // unsupported link arriving as null rather than undefined, and a
        // nullable host allowlist in both directions.
        const linkParsed = await AppstackSDK.handleUniversalLink(
          'https://links.example.com/AbC123?a=1&b=caf%C3%A9%20%F0%9F%9A%80'
        );
        const linkAllowed = await AppstackSDK.handleUniversalLink(
          'https://links.example.com/AbC123',
          { allowedHosts: ['links.example.com'] }
        );
        const linkAllowlistMiss = await AppstackSDK.handleUniversalLink(
          'https://other.example.com/AbC123',
          { allowedHosts: ['links.example.com'] }
        );
        const linkSharedHost = await AppstackSDK.handleUniversalLink(
          'https://appstack.link/AbC123'
        );

        let linkValidationError = '';
        try {
          await AppstackSDK.handleUniversalLink(' ');
        } catch (error) {
          linkValidationError = error && error.message ? error.message : String(error);
        }

        let linkEmptyAllowlistError = '';
        try {
          await AppstackSDK.handleUniversalLink('https://links.example.com/AbC123', {
            allowedHosts: [],
          });
        } catch (error) {
          linkEmptyAllowlistError = error && error.message ? error.message : String(error);
        }

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
          linkBeforeConfigure:
            !!linkBeforeConfigure && linkBeforeConfigure.deeplinkId === 'AbC123',
          linkDeeplinkId: linkParsed ? linkParsed.deeplinkId : null,
          linkQueryParams: linkParsed ? linkParsed.queryParams : null,
          linkUrl: linkParsed ? linkParsed.url : null,
          linkAllowlistHit: !!linkAllowed && linkAllowed.deeplinkId === 'AbC123',
          linkAllowlistMiss:
            linkAllowlistMiss === null ? 'null' : typeof linkAllowlistMiss,
          linkSharedHost: linkSharedHost === null ? 'null' : typeof linkSharedHost,
          linkValidationError,
          linkEmptyAllowlistError,
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
