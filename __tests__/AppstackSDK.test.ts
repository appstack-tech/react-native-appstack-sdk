/**
 * @jest-environment node
 */

// Suppress expected console.error/console.warn from SDK error-path tests (rethrows, platform checks)
const originalError = console.error;
const originalWarn = console.warn;
beforeAll(() => {
  console.error = jest.fn();
  console.warn = jest.fn();
});
afterAll(() => {
  console.error = originalError;
  console.warn = originalWarn;
});

jest.mock('react-native', () => {
  const mockNative = {
    configure: jest.fn().mockResolvedValue(true),
    sendEvent: jest.fn().mockResolvedValue(true),
    enableAppleAdsAttribution: jest.fn().mockResolvedValue(true),
    getAppstackId: jest.fn().mockResolvedValue('test-appstack-id'),
    isSdkDisabled: jest.fn().mockResolvedValue(false),
    getAttributionParams: jest.fn().mockResolvedValue({ campaign: 'test' }),
  };
  return {
    NativeModules: {
      AppstackReactNative: mockNative,
    },
    Platform: {
      OS: 'ios',
      select: function (obj: Record<string, string>) {
        return obj ? obj.ios || obj.default || '' : '';
      },
    },
  };
});

import { NativeModules, Platform } from 'react-native';
import appstackSDK, { AppstackSDK, EventType } from '../src/index';

const mockNative = NativeModules.AppstackReactNative;

beforeEach(() => {
  jest.clearAllMocks();
  mockNative.configure.mockResolvedValue(true);
  mockNative.sendEvent.mockResolvedValue(true);
  mockNative.enableAppleAdsAttribution.mockResolvedValue(true);
  mockNative.getAppstackId.mockResolvedValue('test-appstack-id');
  mockNative.isSdkDisabled.mockResolvedValue(false);
  mockNative.getAttributionParams.mockResolvedValue({});
});

describe('AppstackSDK', () => {
  describe('getInstance', () => {
    it('returns the same singleton instance', () => {
      const a = AppstackSDK.getInstance();
      const b = AppstackSDK.getInstance();
      expect(a).toBe(b);
      expect(appstackSDK).toBe(a);
    });
  });

  describe('configure', () => {
    it('calls native configure with apiKey and defaults', async () => {
      const result = await appstackSDK.configure('my-api-key');
      expect(result).toBe(true);
      expect(mockNative.configure).toHaveBeenCalledTimes(1);
      // isDebug and endpointBaseUrl are validated on the JS side but not forwarded to native.
      expect(mockNative.configure).toHaveBeenCalledWith('my-api-key', 1, null);
    });

    it('calls native configure with all options including customerUserId', async () => {
      const result = await appstackSDK.configure(
        'my-api-key',
        true,
        'https://custom.endpoint/',
        0,
        'user-123'
      );
      expect(result).toBe(true);
      expect(mockNative.configure).toHaveBeenCalledWith('my-api-key', 0, 'user-123');
    });

    it('passes null for optional customerUserId when not provided', async () => {
      await appstackSDK.configure('key', false, undefined, 1);
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, null);
    });

    it('passes null when customerUserId is explicitly null', async () => {
      await appstackSDK.configure('key', false, undefined, 1, null);
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, null);
    });

    it('trims apiKey (endpointBaseUrl is accepted but not forwarded)', async () => {
      await appstackSDK.configure('  key  ', false, '  https://x.com  ', 1);
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, null);
    });

    it('trims customerUserId when provided', async () => {
      await appstackSDK.configure('key', false, undefined, 1, '  user-456  ');
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, 'user-456');
    });

    it('throws when apiKey is empty', async () => {
      await expect(appstackSDK.configure('')).rejects.toThrow('API key must be a non-empty string');
      await expect(appstackSDK.configure('   ')).rejects.toThrow(
        'API key must be a non-empty string'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when apiKey is not a string', async () => {
      await expect(appstackSDK.configure(null as any)).rejects.toThrow();
      await expect(appstackSDK.configure(123 as any)).rejects.toThrow();
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when isDebug is not a boolean', async () => {
      await expect(appstackSDK.configure('key', 'yes' as any)).rejects.toThrow(
        'isDebug must be a boolean'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when endpointBaseUrl is empty string', async () => {
      await expect(appstackSDK.configure('key', false, '')).rejects.toThrow(
        'endpointBaseUrl must be a non-empty string or undefined'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when logLevel is out of range', async () => {
      await expect(appstackSDK.configure('key', false, undefined, -1)).rejects.toThrow(
        'logLevel must be a number between 0 and 3'
      );
      await expect(appstackSDK.configure('key', false, undefined, 4)).rejects.toThrow(
        'logLevel must be a number between 0 and 3'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when customerUserId is empty string', async () => {
      await expect(appstackSDK.configure('key', false, undefined, 1, '')).rejects.toThrow(
        'customerUserId must be a non-empty string, null, or undefined'
      );
      await expect(appstackSDK.configure('key', false, undefined, 1, '   ')).rejects.toThrow(
        'customerUserId must be a non-empty string, null, or undefined'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('rethrows native errors', async () => {
      mockNative.configure.mockRejectedValue(new Error('Native error'));
      await expect(appstackSDK.configure('key')).rejects.toThrow('Native error');
    });
  });

  describe('configure (options object)', () => {
    it('calls native configure with logLevel and customerUserId from the options object', async () => {
      const result = await appstackSDK.configure('my-api-key', {
        logLevel: 0,
        customerUserId: 'user-123',
      });
      expect(result).toBe(true);
      expect(mockNative.configure).toHaveBeenCalledTimes(1);
      expect(mockNative.configure).toHaveBeenCalledWith('my-api-key', 0, 'user-123');
    });

    it('defaults logLevel to 1 and customerUserId to null for an empty options object', async () => {
      await appstackSDK.configure('key', {});
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, null);
    });

    it('accepts logLevel without customerUserId', async () => {
      await appstackSDK.configure('key', { logLevel: 3 });
      expect(mockNative.configure).toHaveBeenCalledWith('key', 3, null);
    });

    it('accepts customerUserId without logLevel', async () => {
      await appstackSDK.configure('key', { customerUserId: 'user-456' });
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, 'user-456');
    });

    it('passes null when customerUserId is explicitly null', async () => {
      await appstackSDK.configure('key', { logLevel: 2, customerUserId: null });
      expect(mockNative.configure).toHaveBeenCalledWith('key', 2, null);
    });

    it('trims apiKey and customerUserId', async () => {
      await appstackSDK.configure('  key  ', { customerUserId: '  user-789  ' });
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, 'user-789');
    });

    it('does not warn about deprecated parameters', async () => {
      await appstackSDK.configure('key', { logLevel: 0, customerUserId: 'user-123' });
      expect(console.warn).not.toHaveBeenCalled();
    });

    it('throws when apiKey is empty', async () => {
      await expect(appstackSDK.configure('   ', { logLevel: 0 })).rejects.toThrow(
        'API key must be a non-empty string'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when logLevel is out of range', async () => {
      await expect(appstackSDK.configure('key', { logLevel: -1 })).rejects.toThrow(
        'logLevel must be a number between 0 and 3'
      );
      await expect(appstackSDK.configure('key', { logLevel: 4 })).rejects.toThrow(
        'logLevel must be a number between 0 and 3'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when logLevel is not a number', async () => {
      await expect(appstackSDK.configure('key', { logLevel: '0' as any })).rejects.toThrow(
        'logLevel must be a number between 0 and 3'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when customerUserId is an empty string', async () => {
      await expect(appstackSDK.configure('key', { customerUserId: '' })).rejects.toThrow(
        'customerUserId must be a non-empty string, null, or undefined'
      );
      await expect(appstackSDK.configure('key', { customerUserId: '   ' })).rejects.toThrow(
        'customerUserId must be a non-empty string, null, or undefined'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('rethrows native errors', async () => {
      mockNative.configure.mockRejectedValue(new Error('Native error'));
      await expect(appstackSDK.configure('key', { logLevel: 0 })).rejects.toThrow('Native error');
    });
  });

  describe('configure (deprecated parameters never reach native)', () => {
    // The native module signature is configure(apiKey, logLevel, customerUserId) — see
    // src/NativeAppstackReactNative.ts. Neither deprecated parameter may leak into it.
    it('drops isDebug and endpointBaseUrl from the legacy positional form', async () => {
      const result = await appstackSDK.configure(
        'my-api-key',
        true,
        'https://custom.endpoint/',
        0,
        'user-123'
      );
      expect(result).toBe(true);
      expect(mockNative.configure).toHaveBeenCalledTimes(1);
      const args = mockNative.configure.mock.calls[0];
      expect(args).toEqual(['my-api-key', 0, 'user-123']);
      expect(args).not.toContain(true);
      expect(args).not.toContain('https://custom.endpoint/');
    });

    it('ignores isDebug and endpointBaseUrl keys smuggled into the options object', async () => {
      await appstackSDK.configure('my-api-key', {
        logLevel: 0,
        customerUserId: 'user-123',
        isDebug: true,
        endpointBaseUrl: 'https://custom.endpoint/',
      } as any);
      const args = mockNative.configure.mock.calls[0];
      expect(args).toEqual(['my-api-key', 0, 'user-123']);
      expect(args).not.toContain(true);
      expect(args).not.toContain('https://custom.endpoint/');
    });

    it('warns when isDebug is passed positionally', async () => {
      await appstackSDK.configure('key', true);
      expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('isDebug'));
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, null);
    });

    it('warns when endpointBaseUrl is passed positionally', async () => {
      await appstackSDK.configure('key', false, 'https://custom.endpoint/');
      expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('endpointBaseUrl'));
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, null);
    });

    it('does not warn when the legacy form omits both deprecated parameters', async () => {
      await appstackSDK.configure('key', false, undefined, 0, 'user-123');
      expect(console.warn).not.toHaveBeenCalled();
      expect(mockNative.configure).toHaveBeenCalledWith('key', 0, 'user-123');
    });
  });

  describe('sendEvent', () => {
    it('sends event with eventType only', async () => {
      const result = await appstackSDK.sendEvent(EventType.PURCHASE);
      expect(result).toBe(true);
      expect(mockNative.sendEvent).toHaveBeenCalledWith('PURCHASE', null, null);
    });

    it('sends event with eventType string', async () => {
      await appstackSDK.sendEvent('LOGIN');
      expect(mockNative.sendEvent).toHaveBeenCalledWith('LOGIN', null, null);
    });

    it('sends event with eventType, eventName and parameters', async () => {
      await appstackSDK.sendEvent(EventType.PURCHASE, null, { revenue: 29.99, currency: 'USD' });
      expect(mockNative.sendEvent).toHaveBeenCalledWith('PURCHASE', null, {
        revenue: 29.99,
        currency: 'USD',
      });
    });

    it('sends CUSTOM event with eventName', async () => {
      await appstackSDK.sendEvent(EventType.CUSTOM, 'my_custom_event');
      expect(mockNative.sendEvent).toHaveBeenCalledWith('CUSTOM', 'my_custom_event', null);
    });

    it('sends event with legacy eventName only', async () => {
      await appstackSDK.sendEvent(undefined, 'SIGN_UP');
      expect(mockNative.sendEvent).toHaveBeenCalledWith(null, 'SIGN_UP', null);
    });

    it('throws when both eventType and eventName are missing', async () => {
      await expect(appstackSDK.sendEvent(undefined, undefined)).rejects.toThrow(
        'Either eventName or eventType must be provided'
      );
      await expect(appstackSDK.sendEvent('', '')).rejects.toThrow(
        'Either eventName or eventType must be provided'
      );
      expect(mockNative.sendEvent).not.toHaveBeenCalled();
    });

    it('rethrows native errors', async () => {
      mockNative.sendEvent.mockRejectedValue(new Error('Send failed'));
      await expect(appstackSDK.sendEvent('PURCHASE')).rejects.toThrow('Send failed');
    });
  });

  describe('enableAppleAdsAttribution', () => {
    it('calls native and returns result on iOS', async () => {
      (Platform as any).OS = 'ios';
      const result = await appstackSDK.enableAppleAdsAttribution();
      expect(result).toBe(true);
      expect(mockNative.enableAppleAdsAttribution).toHaveBeenCalledTimes(1);
    });

    it('returns false without calling native on Android', async () => {
      (Platform as any).OS = 'android';
      const result = await appstackSDK.enableAppleAdsAttribution();
      expect(result).toBe(false);
      expect(mockNative.enableAppleAdsAttribution).not.toHaveBeenCalled();
    });

    it('rethrows native errors on iOS', async () => {
      (Platform as any).OS = 'ios';
      mockNative.enableAppleAdsAttribution.mockRejectedValue(new Error('ASA error'));
      await expect(appstackSDK.enableAppleAdsAttribution()).rejects.toThrow('ASA error');
    });
  });

  describe('getAppstackId', () => {
    it('returns appstack id from native', async () => {
      mockNative.getAppstackId.mockResolvedValue('id-xyz');
      const id = await appstackSDK.getAppstackId();
      expect(id).toBe('id-xyz');
      expect(mockNative.getAppstackId).toHaveBeenCalledTimes(1);
    });

    it('rethrows native errors', async () => {
      mockNative.getAppstackId.mockRejectedValue(new Error('Native error'));
      await expect(appstackSDK.getAppstackId()).rejects.toThrow('Native error');
    });
  });

  describe('isSdkDisabled', () => {
    it('returns false when SDK is enabled', async () => {
      mockNative.isSdkDisabled.mockResolvedValue(false);
      const disabled = await appstackSDK.isSdkDisabled();
      expect(disabled).toBe(false);
    });

    it('returns true when SDK is disabled', async () => {
      mockNative.isSdkDisabled.mockResolvedValue(true);
      const disabled = await appstackSDK.isSdkDisabled();
      expect(disabled).toBe(true);
    });

    it('rethrows native errors', async () => {
      mockNative.isSdkDisabled.mockRejectedValue(new Error('Native error'));
      await expect(appstackSDK.isSdkDisabled()).rejects.toThrow('Native error');
    });
  });

  describe('getAttributionParams', () => {
    it('returns attribution params from native', async () => {
      const params = { campaign: 'test', source: 'organic' };
      mockNative.getAttributionParams.mockResolvedValue(params);
      const result = await appstackSDK.getAttributionParams();
      expect(result).toEqual(params);
      expect(mockNative.getAttributionParams).toHaveBeenCalledTimes(1);
    });

    it('rethrows native errors', async () => {
      mockNative.getAttributionParams.mockRejectedValue(new Error('Native error'));
      await expect(appstackSDK.getAttributionParams()).rejects.toThrow('Native error');
    });
  });
});

describe('EventType', () => {
  it('exports expected event types', () => {
    expect(EventType.INSTALL).toBe('INSTALL');
    expect(EventType.LOGIN).toBe('LOGIN');
    expect(EventType.PURCHASE).toBe('PURCHASE');
    expect(EventType.CUSTOM).toBe('CUSTOM');
    expect(EventType.SIGN_UP).toBe('SIGN_UP');
    expect(EventType.REGISTER).toBe('REGISTER');
  });
});
