const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

// Add the parent directory to watchFolders so Metro can watch for changes
config.watchFolders = [
  path.resolve(__dirname, '..'), // Parent directory containing the SDK
];

// Add resolver configuration to help with symlinks
config.resolver = {
  ...config.resolver,
  // Enable symlink resolution
  unstable_enableSymlinks: true,
  // Node modules paths to check
  nodeModulesPaths: [
    path.resolve(__dirname, 'node_modules'),
    path.resolve(__dirname, '..', 'node_modules'),
  ],
};

module.exports = config;
