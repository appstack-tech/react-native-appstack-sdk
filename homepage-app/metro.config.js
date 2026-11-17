const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

config.watchFolders = [
  path.resolve(__dirname, '..'),
];

// The SDK is installed from the parent folder ("file:.."), so Metro bundles its
// `src/` from the repo root. Hierarchical lookup from there finds the SDK's own
// dev install in ../node_modules (React 18 / React Native 0.72), which would put a
// second React and React Native in the bundle. Always resolve the SDK's peer
// dependencies from this app.
const SINGLETONS = ['react', 'react-native'];
const appOrigin = path.join(__dirname, 'package.json');

config.resolver = {
  ...config.resolver,
  nodeModulesPaths: [
    path.resolve(__dirname, 'node_modules'),
    path.resolve(__dirname, '..', 'node_modules'),
  ],
  resolveRequest: (context, moduleName, platform) => {
    if (SINGLETONS.some((name) => moduleName === name || moduleName.startsWith(`${name}/`))) {
      return context.resolveRequest({ ...context, originModulePath: appOrigin }, moduleName, platform);
    }
    return context.resolveRequest(context, moduleName, platform);
  },
};

module.exports = config;
