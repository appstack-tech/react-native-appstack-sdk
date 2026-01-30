const pkg = require('../../package.json');

// Try to import @expo/config-plugins, but provide fallback if not available
let createRunOncePlugin: any;

try {
  const configPlugins = require('@expo/config-plugins');
  createRunOncePlugin = configPlugins.createRunOncePlugin;
} catch {
  console.warn('@expo/config-plugins not available, using fallback plugin implementation');
}

/**
 * Full-featured plugin using @expo/config-plugins
 * No Android modifications needed - React Native autolinking handles everything
 */
const withAppstackSDKFull = (config: any) => {
  // No Android modifications needed - autolinking handles everything via react-native.config.js
  return config;
};

/**
 * Main plugin function
 */
const withAppstackSDK = (config: any) => {
  // Apply Android modifications
  config = withAppstackSDKFull(config);
  return config;
};

// Export the plugin with fallback support
const plugin = createRunOncePlugin
  ? createRunOncePlugin(withAppstackSDK, pkg.name, pkg.version)
  : withAppstackSDK;
export default plugin;
