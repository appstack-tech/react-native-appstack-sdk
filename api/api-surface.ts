// Type-only "API tester": exercises every public export the way an app would.
// Checked by `npm run api:check` (tsc -p tsconfig.api.json), never executed or
// shipped. Removing an export, or changing a signature so existing callers stop
// compiling, fails here even if the api-extractor report was regenerated.
//
// Imports resolve to lib/typescript (the declarations npm ships), not src/, so
// this sees exactly what an app sees.
import AppstackSDKDefault, { AppstackSDK, EventType } from 'react-native-appstack-sdk';
import type {
  AppstackConfigureOptions,
  AppstackEventParameters,
  AppstackLinkOptions,
  AppstackLinkResult,
  AppstackSDKInterface,
  JsonValue,
} from 'react-native-appstack-sdk';

// Exact type equality, so a narrowed or widened return type fails too.
type Equals<A, B> = (<T>() => T extends A ? 1 : 2) extends <T>() => T extends B ? 1 : 2
  ? true
  : false;
const expectType =
  <Expected>() =>
  <Actual>(_value: Actual & (Equals<Actual, Expected> extends true ? unknown : never)) =>
    undefined;

// An app's own implementation of the exported interface, e.g. a test mock.
// Written against today's interface and deliberately not updated when it grows:
// a new required member breaks implementers like this one, so it fails here.
export class ConsumerMock implements AppstackSDKInterface {
  async configure(_apiKey: string, _options?: AppstackConfigureOptions | null) {
    return true;
  }
  async setCustomerUserId(_customerUserId?: string | null) {}
  async deleteUserData() {}
  async sendEvent(_event: EventType | string, _parameters?: AppstackEventParameters | null) {}
  async enableAppleAdsAttribution() {
    return false;
  }
  async getAppstackId() {
    return 'appstack-id';
  }
  async isSdkDisabled() {
    return false;
  }
  async getAttributionParams(): Promise<Record<string, any>> {
    return {};
  }
  async handleUniversalLink(
    _url: string,
    _options?: AppstackLinkOptions | null
  ): Promise<AppstackLinkResult | null> {
    return null;
  }
}

export async function exerciseApi(): Promise<void> {
  // The default export is the singleton, typed as the class.
  const sdk: AppstackSDK = AppstackSDKDefault;
  const iface: AppstackSDKInterface = sdk;
  expectType<AppstackSDK>()(AppstackSDK.getInstance());

  // configure
  const options: AppstackConfigureOptions = { logLevel: 0, customerUserId: 'user-123' };
  expectType<Promise<boolean>>()(sdk.configure('api-key'));
  expectType<Promise<boolean>>()(sdk.configure('api-key', options));
  expectType<Promise<boolean>>()(sdk.configure('api-key', { customerUserId: null }));
  expectType<Promise<boolean>>()(sdk.configure('api-key', null));
  // @ts-expect-error The 2.x positional form was removed in 3.0.
  sdk.configure('api-key', false, undefined, 1, 'user-123');

  // setCustomerUserId
  expectType<Promise<void>>()(sdk.setCustomerUserId('user-123'));
  expectType<Promise<void>>()(sdk.setCustomerUserId(null));
  expectType<Promise<void>>()(sdk.setCustomerUserId());

  // deleteUserData
  expectType<Promise<void>>()(sdk.deleteUserData());

  // sendEvent
  const nested: JsonValue = { items: [{ sku: 'a', qty: 2 }], gift: false, note: null };
  const parameters: AppstackEventParameters = {
    revenue: 29.99,
    currency: 'USD',
    nested,
    stripped: undefined,
  };
  expectType<Promise<void>>()(sdk.sendEvent(EventType.PURCHASE));
  expectType<Promise<void>>()(sdk.sendEvent(EventType.PURCHASE, parameters));
  expectType<Promise<void>>()(sdk.sendEvent('user_attributes', { email: 'a@b.com' }));
  expectType<Promise<void>>()(sdk.sendEvent('PURCHASE', null));
  // @ts-expect-error The 2.x (eventType, eventName, parameters) form was removed in 3.0.
  sdk.sendEvent('CUSTOM', 'my_event', {});
  // @ts-expect-error Parameters must be JSON-serialisable.
  sdk.sendEvent(EventType.PURCHASE, { at: new Date() });

  // Apple Ads, identity and state
  expectType<Promise<boolean>>()(sdk.enableAppleAdsAttribution());
  expectType<Promise<string>>()(sdk.getAppstackId());
  expectType<Promise<boolean>>()(sdk.isSdkDisabled());
  expectType<Promise<Record<string, any>>>()(sdk.getAttributionParams());

  // handleUniversalLink
  const linkOptions: AppstackLinkOptions = { allowedHosts: ['links.example.com'] };
  expectType<Promise<AppstackLinkResult | null>>()(
    sdk.handleUniversalLink('https://links.example.com/abc')
  );
  expectType<Promise<AppstackLinkResult | null>>()(
    iface.handleUniversalLink('https://links.example.com/abc', linkOptions)
  );
  const link = await sdk.handleUniversalLink('https://links.example.com/abc', null);
  if (link) {
    expectType<string>()(link.deeplinkId);
    expectType<Record<string, string>>()(link.queryParams);
    expectType<string>()(link.url);
  }

  // EventType: every current member. Adding one is fine; removing or renaming
  // one fails here.
  const eventTypes: readonly EventType[] = [
    EventType.INSTALL,
    EventType.LOGIN,
    EventType.SIGN_UP,
    EventType.REGISTER,
    EventType.PURCHASE,
    EventType.ADD_TO_CART,
    EventType.ADD_TO_WISHLIST,
    EventType.INITIATE_CHECKOUT,
    EventType.START_TRIAL,
    EventType.SUBSCRIBE,
    EventType.LEVEL_START,
    EventType.LEVEL_COMPLETE,
    EventType.TUTORIAL_COMPLETE,
    EventType.SEARCH,
    EventType.VIEW_ITEM,
    EventType.VIEW_CONTENT,
    EventType.SHARE,
  ];
  await Promise.all(eventTypes.map((eventType) => sdk.sendEvent(eventType)));

  // The wire value of every member is its own name (sendEvent relies on it).
  const wireValues: { [K in keyof typeof EventType]: `${(typeof EventType)[K]}` } = EventType;
  const valuesAreNames: { [K in keyof typeof EventType]: K } = wireValues;
  expectType<'PURCHASE'>()(valuesAreNames.PURCHASE);

  // @ts-expect-error The SDK is a singleton; use the default export or getInstance().
  const forbidden = new AppstackSDK();
  expectType<AppstackSDK>()(forbidden);
}
