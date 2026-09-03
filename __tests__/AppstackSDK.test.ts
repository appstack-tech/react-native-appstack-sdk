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
    setCustomerUserId: jest.fn().mockResolvedValue(undefined),
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
    // src/index.ts resolves the native module through the codegen spec, which
    // uses TurboModuleRegistry. Return the same object so the assertions below
    // can keep reading it off NativeModules.
    TurboModuleRegistry: {
      get: () => mockNative,
      getEnforcing: () => mockNative,
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
  mockNative.setCustomerUserId.mockResolvedValue(undefined);
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
      expect(mockNative.configure).toHaveBeenCalledWith('my-api-key', 1, null);
    });

    it('treats an explicit null options argument as no options', async () => {
      await appstackSDK.configure('key', null);
      expect(mockNative.configure).toHaveBeenCalledWith('key', 1, null);
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
        'logLevel must be one of 0, 1, 2, or 3'
      );
      await expect(appstackSDK.configure('key', { logLevel: 4 })).rejects.toThrow(
        'logLevel must be one of 0, 1, 2, or 3'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when logLevel is not a number', async () => {
      await expect(appstackSDK.configure('key', { logLevel: '0' as any })).rejects.toThrow(
        'logLevel must be one of 0, 1, 2, or 3'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('throws when logLevel is NaN', async () => {
      // typeof NaN === 'number' and both NaN < 0 and NaN > 3 are false, so a plain
      // range check lets it through to native.
      await expect(appstackSDK.configure('key', { logLevel: NaN })).rejects.toThrow(
        'logLevel must be one of 0, 1, 2, or 3'
      );
      await expect(appstackSDK.configure('key', { logLevel: Number('nope') })).rejects.toThrow(
        'logLevel must be one of 0, 1, 2, or 3'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    // A fraction passes typeof, Number.isFinite and the 0-3 range check, then gets
    // silently truncated by the native casts (1.5 -> 1). Only integers are valid.
    it.each([1.5, 0.5, 2.9, -0.5, 3.5])(
      'throws when logLevel is the fraction %p',
      async (level) => {
        await expect(appstackSDK.configure('key', { logLevel: level })).rejects.toThrow(
          'logLevel must be one of 0, 1, 2, or 3'
        );
        expect(mockNative.configure).not.toHaveBeenCalled();
      }
    );

    it('still accepts every valid integer level', async () => {
      for (const level of [0, 1, 2, 3]) {
        jest.clearAllMocks();
        await appstackSDK.configure('key', { logLevel: level });
        expect(mockNative.configure).toHaveBeenCalledWith('key', level, null);
      }
    });

    it('accepts Infinity as invalid rather than clamping it', async () => {
      await expect(appstackSDK.configure('key', { logLevel: Infinity })).rejects.toThrow(
        'logLevel must be one of 0, 1, 2, or 3'
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

  describe('configure (removed positional signature)', () => {
    // The native module signature is configure(apiKey, logLevel, customerUserId) — see
    // src/NativeAppstackReactNative.ts. A 2.x positional call must fail loudly rather
    // than silently drop the logLevel and customerUserId that follow isDebug.
    //
    // Detection is by argument count, not by the second argument's type: isDebug was
    // almost always `false` and endpointBaseUrl almost always `undefined` in real 2.x
    // code, so their values are not a usable signal.
    it.each([
      ['isDebug false', false],
      ['isDebug true', true],
      ['isDebug null', null],
      ['isDebug undefined', undefined],
      ['a stray endpoint string', 'https://custom.endpoint/'],
      ['a half-migrated options object', { logLevel: 0 }],
    ])('rejects a 5-argument positional call with %s in slot 2', async (_label, secondArg) => {
      await expect(
        (appstackSDK.configure as any)('my-api-key', secondArg, 'https://custom.endpoint/', 0, 'u')
      ).rejects.toThrow('was removed in 3.0');
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('rejects a trailing positional argument even without the full 2.x tail', async () => {
      await expect(
        (appstackSDK.configure as any)('key', { logLevel: 0 }, undefined)
      ).rejects.toThrow('was removed in 3.0');
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('rejects a non-object second argument on its own', async () => {
      await expect((appstackSDK.configure as any)('key', false)).rejects.toThrow(
        'was removed in 3.0'
      );
      expect(mockNative.configure).not.toHaveBeenCalled();
    });

    it('names the replacement in the migration error', async () => {
      await expect((appstackSDK.configure as any)('key', false)).rejects.toThrow(
        'configure(apiKey, { logLevel, customerUserId })'
      );
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

    it('never warns: the deprecation warnings are gone with the signature', async () => {
      await appstackSDK.configure('key', { logLevel: 0, customerUserId: 'user-123' });
      expect(console.warn).not.toHaveBeenCalled();
    });
  });

  describe('setCustomerUserId', () => {
    it('forwards a trimmed id to native', async () => {
      await appstackSDK.setCustomerUserId('  user-123  ');
      expect(mockNative.setCustomerUserId).toHaveBeenCalledTimes(1);
      expect(mockNative.setCustomerUserId).toHaveBeenCalledWith('user-123');
    });

    it('passes null through to the native clear path', async () => {
      await appstackSDK.setCustomerUserId(null);
      expect(mockNative.setCustomerUserId).toHaveBeenCalledWith(null);
    });

    it('normalizes undefined and a missing argument to an explicit null', async () => {
      await appstackSDK.setCustomerUserId(undefined);
      await appstackSDK.setCustomerUserId();
      expect(mockNative.setCustomerUserId).toHaveBeenNthCalledWith(1, null);
      expect(mockNative.setCustomerUserId).toHaveBeenNthCalledWith(2, null);
    });

    // A blank id must NOT be rejected here: it is a legitimate clear.
    it('clears instead of throwing for an empty or whitespace id', async () => {
      await appstackSDK.setCustomerUserId('');
      await appstackSDK.setCustomerUserId('   ');
      expect(mockNative.setCustomerUserId).toHaveBeenCalledTimes(2);
      expect(mockNative.setCustomerUserId).toHaveBeenNthCalledWith(1, null);
      expect(mockNative.setCustomerUserId).toHaveBeenNthCalledWith(2, null);
    });

    it('throws without calling native when the id is not a string', async () => {
      await expect(appstackSDK.setCustomerUserId(123 as any)).rejects.toThrow(
        'customerUserId must be a string, null, or undefined'
      );
      expect(mockNative.setCustomerUserId).not.toHaveBeenCalled();
    });

    it('rethrows native errors', async () => {
      mockNative.setCustomerUserId.mockRejectedValue(new Error('Native error'));
      await expect(appstackSDK.setCustomerUserId('user-123')).rejects.toThrow('Native error');
    });

    it('leaves configure validation untouched', async () => {
      await expect(appstackSDK.configure('key', { customerUserId: '' })).rejects.toThrow(
        'customerUserId must be a non-empty string, null, or undefined'
      );
      await appstackSDK.setCustomerUserId('');
      expect(mockNative.setCustomerUserId).toHaveBeenCalledWith(null);
    });
  });

  describe('sendEvent', () => {
    describe('standard events', () => {
      it('sends an EventType member as a standard type with no name', async () => {
        const result = await appstackSDK.sendEvent(EventType.PURCHASE);
        // Promise<void>: the old `true` implied delivery, which native never promised.
        expect(result).toBeUndefined();
        expect(mockNative.sendEvent).toHaveBeenCalledWith('PURCHASE', null, null);
      });

      it('treats the equivalent string as the same standard type', async () => {
        await appstackSDK.sendEvent('LOGIN');
        expect(mockNative.sendEvent).toHaveBeenCalledWith('LOGIN', null, null);
      });

      it('resolves standard types case-insensitively and canonicalises them', async () => {
        await appstackSDK.sendEvent('purchase');
        expect(mockNative.sendEvent).toHaveBeenCalledWith('PURCHASE', null, null);

        await appstackSDK.sendEvent('Add_To_Cart');
        expect(mockNative.sendEvent).toHaveBeenCalledWith('ADD_TO_CART', null, null);
      });

      it('trims surrounding whitespace before resolving', async () => {
        await appstackSDK.sendEvent('  SUBSCRIBE  ');
        expect(mockNative.sendEvent).toHaveBeenCalledWith('SUBSCRIBE', null, null);
      });

      it('forwards parameters alongside a standard type', async () => {
        await appstackSDK.sendEvent(EventType.PURCHASE, { revenue: 29.99, currency: 'USD' });
        expect(mockNative.sendEvent).toHaveBeenCalledWith('PURCHASE', null, {
          revenue: 29.99,
          currency: 'USD',
        });
      });
    });

    describe('custom events', () => {
      it('sends an unrecognised string as a CUSTOM event named after it', async () => {
        await appstackSDK.sendEvent('user_attributes', { email: 'a@b.com' });
        expect(mockNative.sendEvent).toHaveBeenCalledWith('CUSTOM', 'user_attributes', {
          email: 'a@b.com',
        });
      });

      it('preserves the caller casing of a custom name', async () => {
        await appstackSDK.sendEvent('My_Custom_Event');
        expect(mockNative.sendEvent).toHaveBeenCalledWith('CUSTOM', 'My_Custom_Event', null);
      });

      // The bug this API removes: iOS sent this as a custom event while Android
      // rejected it with INVALID_EVENT_NAME. JS now resolves the pair itself, so
      // both platforms receive the same explicit ('CUSTOM', name) arguments.
      it('sends a bare unknown event identically on both platforms', async () => {
        await appstackSDK.sendEvent('MY_CUSTOM_EVENT');
        expect(mockNative.sendEvent).toHaveBeenCalledWith('CUSTOM', 'MY_CUSTOM_EVENT', null);
      });

      it("rejects the literal 'CUSTOM' and points at the custom-name form", async () => {
        await expect(appstackSDK.sendEvent('CUSTOM')).rejects.toThrow(
          "'CUSTOM' is not a sendable event"
        );
        await expect(appstackSDK.sendEvent('custom')).rejects.toThrow(
          "'CUSTOM' is not a sendable event"
        );
        expect(mockNative.sendEvent).not.toHaveBeenCalled();
      });
    });

    describe('automatic-only events', () => {
      // iOS drops these natively; FIRST_OPEN* are not in Android's enum at all, so
      // forwarding would fabricate a custom event named "FIRST_OPEN" on Android only.
      it.each(['INSTALL', 'FIRST_OPEN', 'FIRST_OPEN_GUARDED', 'ASA_ATTRIBUTION'])(
        'drops %s without calling native and without rejecting',
        async (event) => {
          await expect(appstackSDK.sendEvent(event)).resolves.toBeUndefined();
          expect(mockNative.sendEvent).not.toHaveBeenCalled();
          expect(console.error).toHaveBeenCalledWith(
            expect.stringContaining('recorded automatically by the SDK')
          );
        }
      );

      it('drops them case-insensitively', async () => {
        await appstackSDK.sendEvent('install');
        await appstackSDK.sendEvent('  First_Open  ');
        expect(mockNative.sendEvent).not.toHaveBeenCalled();
      });

      it('does not warn about them being non-standard', async () => {
        (globalThis as Record<string, unknown>).__DEV__ = true;
        try {
          await appstackSDK.sendEvent('FIRST_OPEN');
          expect(console.warn).not.toHaveBeenCalled();
        } finally {
          delete (globalThis as Record<string, unknown>).__DEV__;
        }
      });
    });

    describe('parameter normalisation', () => {
      it('strips null and undefined values so both platforms see one map', async () => {
        await appstackSDK.sendEvent(EventType.PURCHASE, {
          revenue: 4.99,
          currency: null,
          coupon: undefined,
          quantity: 0,
          gift: false,
          note: '',
        });
        // 0, false and '' are real values and must survive; only nullish keys go.
        expect(mockNative.sendEvent).toHaveBeenCalledWith('PURCHASE', null, {
          revenue: 4.99,
          quantity: 0,
          gift: false,
          note: '',
        });
      });

      it('collapses an empty or all-nullish map to null', async () => {
        await appstackSDK.sendEvent(EventType.LOGIN, {});
        expect(mockNative.sendEvent).toHaveBeenLastCalledWith('LOGIN', null, null);

        await appstackSDK.sendEvent(EventType.LOGIN, { a: null, b: undefined });
        expect(mockNative.sendEvent).toHaveBeenLastCalledWith('LOGIN', null, null);
      });

      it('accepts an explicit null for parameters', async () => {
        await appstackSDK.sendEvent(EventType.LOGIN, null);
        expect(mockNative.sendEvent).toHaveBeenCalledWith('LOGIN', null, null);
      });

      it('keeps nested structures intact', async () => {
        await appstackSDK.sendEvent('cart_view', { items: [{ id: 1 }], meta: { a: null } });
        expect(mockNative.sendEvent).toHaveBeenCalledWith('CUSTOM', 'cart_view', {
          items: [{ id: 1 }],
          // Stripping is shallow, matching Android's filterValues.
          meta: { a: null },
        });
      });
    });

    describe('removed 3-argument signature', () => {
      it('throws on a three-argument call', async () => {
        await expect(
          (appstackSDK.sendEvent as (...args: unknown[]) => Promise<void>)('PURCHASE', null, {
            revenue: 29.99,
          })
        ).rejects.toThrow('sendEvent(eventType, eventName, parameters) was removed in 3.0');
        expect(mockNative.sendEvent).not.toHaveBeenCalled();
      });

      // The previously documented way to send a custom event. Two arguments, so the
      // arity check alone misses it: without the shape check the name would bind to
      // `parameters` and ship an event whose payload is its own name.
      it('throws when the second argument is a name string', async () => {
        await expect(
          (appstackSDK.sendEvent as (...args: unknown[]) => Promise<void>)(
            'CUSTOM',
            'my_custom_event'
          )
        ).rejects.toThrow('sendEvent(eventType, eventName, parameters) was removed in 3.0');
        expect(mockNative.sendEvent).not.toHaveBeenCalled();
      });

      it('throws when parameters is an array', async () => {
        await expect(
          (appstackSDK.sendEvent as (...args: unknown[]) => Promise<void>)('PURCHASE', [1, 2])
        ).rejects.toThrow('sendEvent(eventType, eventName, parameters) was removed in 3.0');
        expect(mockNative.sendEvent).not.toHaveBeenCalled();
      });
    });

    describe('validation and errors', () => {
      it('throws when the event is missing, blank or not a string', async () => {
        const calls: unknown[] = [undefined, null, '', '   ', 42, {}];
        for (const value of calls) {
          await expect(
            (appstackSDK.sendEvent as (...args: unknown[]) => Promise<void>)(value)
          ).rejects.toThrow('event must be a non-empty string');
        }
        expect(mockNative.sendEvent).not.toHaveBeenCalled();
      });

      it('rethrows native errors', async () => {
        mockNative.sendEvent.mockRejectedValue(new Error('Send failed'));
        await expect(appstackSDK.sendEvent('PURCHASE')).rejects.toThrow('Send failed');
      });

      // Documented guarantee: sendEvent is async, so validation failures reject the
      // returned promise instead of throwing synchronously. Callers who fire and
      // forget need a .catch(); a synchronous pre-check added later would break them.
      it('rejects rather than throwing synchronously', async () => {
        let promise: Promise<void>;
        expect(() => {
          promise = appstackSDK.sendEvent('CUSTOM');
        }).not.toThrow();
        await expect(promise!).rejects.toThrow("'CUSTOM' is not a sendable event");
      });
    });

    describe('development-only warning', () => {
      afterEach(() => {
        delete (globalThis as Record<string, unknown>).__DEV__;
      });

      it('warns that an unrecognised event is being sent as custom', async () => {
        (globalThis as Record<string, unknown>).__DEV__ = true;
        await appstackSDK.sendEvent('PURCAHSE');
        expect(console.warn).toHaveBeenCalledWith(
          expect.stringContaining("'PURCAHSE' is not a standard EventType")
        );
        // Advisory only: the send still happens.
        expect(mockNative.sendEvent).toHaveBeenCalledWith('CUSTOM', 'PURCAHSE', null);
      });

      it('stays silent for standard events', async () => {
        (globalThis as Record<string, unknown>).__DEV__ = true;
        await appstackSDK.sendEvent(EventType.PURCHASE);
        expect(console.warn).not.toHaveBeenCalled();
      });

      // Guards the `typeof __DEV__` check: a bare reference would be a ReferenceError
      // wherever the global is not injected (plain Node, some bundlers, this suite).
      it('does not throw or warn when __DEV__ is undefined', async () => {
        expect(typeof (globalThis as Record<string, unknown>).__DEV__).toBe('undefined');
        await expect(appstackSDK.sendEvent('user_attributes')).resolves.toBeUndefined();
        expect(console.warn).not.toHaveBeenCalled();
      });
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

// The on-device probe in integration-tests/run.sh drives the public API and
// integration-tests/validate_runtime.py asserts on what it reports and on the event
// payloads captured at the wire. Those run only on an emulator/simulator in CI
// (~20 min), so this mirrors the same contract here: an API change that breaks the
// probe fails in milliseconds instead of at the gate. Keep in sync with both files.
describe('integration-test runtime contract', () => {
  it('matches what validate_runtime.py requires', async () => {
    // The three sends the probe performs. A rejection here aborts the probe's try
    // block and reports failure, so there is no return value worth asserting —
    // what matters is the (type, name) pair each one hands to native, which is
    // exactly what the validator later matches by event_name at the wire.
    await appstackSDK.sendEvent('runtime_validation_custom', {
      string: 'bridge-value',
      number: 42,
      decimal: 9.75,
      boolean: true,
      unicode: 'café 🚀',
      array: ['one', 2, false],
      nested: { enabled: true, items: ['nested', 3, false] },
    });
    expect(mockNative.sendEvent).toHaveBeenLastCalledWith(
      'CUSTOM',
      'runtime_validation_custom',
      expect.objectContaining({
        unicode: 'café 🚀',
        nested: { enabled: true, items: ['nested', 3, false] },
      })
    );

    await appstackSDK.sendEvent(EventType.LOGIN, { state: 'ready', sequence: 2 });
    expect(mockNative.sendEvent).toHaveBeenLastCalledWith('LOGIN', null, {
      state: 'ready',
      sequence: 2,
    });

    await appstackSDK.sendEvent('runtime_validation_bare');
    expect(mockNative.sendEvent).toHaveBeenLastCalledWith(
      'CUSTOM',
      'runtime_validation_bare',
      null
    );

    // The two flags the probe still reports.
    let validationError = '';
    try {
      await (appstackSDK.sendEvent as (...args: unknown[]) => Promise<void>)();
    } catch (error) {
      validationError = error instanceof Error ? error.message : String(error);
    }
    expect(validationError.startsWith('event must be a non-empty string')).toBe(true);

    let legacyCallRejected = false;
    try {
      await (appstackSDK.sendEvent as (...args: unknown[]) => Promise<void>)('PURCHASE', null, {
        revenue: 1.5,
      });
    } catch (error) {
      legacyCallRejected = /removed in 3\.0/.test(
        error instanceof Error ? error.message : String(error)
      );
    }
    expect(legacyCallRejected).toBe(true);
  });
});

describe('EventType', () => {
  it('exports expected event types', () => {
    expect(EventType.INSTALL).toBe('INSTALL');
    expect(EventType.LOGIN).toBe('LOGIN');
    expect(EventType.PURCHASE).toBe('PURCHASE');
    expect(EventType.SIGN_UP).toBe('SIGN_UP');
    expect(EventType.REGISTER).toBe('REGISTER');
  });

  // Removed in 3.0: in the two-argument API you pass a custom event's name
  // directly, so CUSTOM had no caller-facing meaning and was a footgun —
  // sendEvent(EventType.CUSTOM, params) resolved as "standard type CUSTOM, no
  // name", which iOS drops and Android sends with a null event_name.
  it('no longer exports CUSTOM', () => {
    expect((EventType as Record<string, string>).CUSTOM).toBeUndefined();
    expect(Object.values(EventType)).not.toContain('CUSTOM');
  });

  // The JS enum must stay aligned with Android's native enum: JS resolves the
  // standard/custom decision now, so a member missing here silently downgrades a
  // standard event to a custom one.
  it('matches the 17 standard types the wrapper can resolve', () => {
    expect(Object.values(EventType)).toEqual([
      'INSTALL',
      'LOGIN',
      'SIGN_UP',
      'REGISTER',
      'PURCHASE',
      'ADD_TO_CART',
      'ADD_TO_WISHLIST',
      'INITIATE_CHECKOUT',
      'START_TRIAL',
      'SUBSCRIBE',
      'LEVEL_START',
      'LEVEL_COMPLETE',
      'TUTORIAL_COMPLETE',
      'SEARCH',
      'VIEW_ITEM',
      'VIEW_CONTENT',
      'SHARE',
    ]);
  });
});
