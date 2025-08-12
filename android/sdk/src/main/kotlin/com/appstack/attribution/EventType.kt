package com.appstack.attribution

/**
 * Standard attribution events supported by the SDK.
 *
 * The enum constant names follow the widely adopted snake-case notation used by
 * mobile measurement partners (MMPs). The raw value sent over the wire is the
 * enum name itself (e.g. `EventType.ADD_TO_CART.name` → "ADD_TO_CART").
 *
 * For events that have synonymous names (e.g. SIGN_UP/REGISTER), both variants
 * are provided to maximise compatibility with existing integrations.
 */
enum class EventType {
    // --- Lifecycle ---
    /** User installs the app (tracked automatically by the SDK). */
    INSTALL,

    // --- Authentication & account ---
    /** User logs in to an existing account. */
    LOGIN,
    /** User signs up for a new account. */
    SIGN_UP,
    /** Alias for SIGN_UP – kept for compatibility with some MMPs. */
    REGISTER,

    // --- Monetisation ---
    /** User completes a purchase (often includes revenue & currency). */
    PURCHASE,
    /** Item added to the shopping cart. */
    ADD_TO_CART,
    /** Item added to the wishlist. */
    ADD_TO_WISHLIST,
    /** Checkout process started. */
    INITIATE_CHECKOUT,
    /** User starts a free trial. */
    START_TRIAL,
    /** User subscribes to a paid plan. */
    SUBSCRIBE,

    // --- Games / progression ---
    /** User starts a new level (games). */
    LEVEL_START,
    /** User completes a level (games). */
    LEVEL_COMPLETE,

    // --- Engagement ---
    /** User completes the onboarding tutorial. */
    TUTORIAL_COMPLETE,
    /** User performs a search in the app. */
    SEARCH,
    /** User views a specific product or item. */
    VIEW_ITEM,
    /** User views generic content (e.g. article, post). */
    VIEW_CONTENT,
    /** User shares content from the app. */
    SHARE,

    // --- Catch-all ---
    /** Custom application-specific event not covered above. */
    CUSTOM,
} 