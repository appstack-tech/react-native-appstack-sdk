const reactNativePreset = require('react-native/jest-preset');

module.exports = {
  ...reactNativePreset,
  setupFiles: [],
  modulePathIgnorePatterns: ['<rootDir>/example/node_modules', '<rootDir>/lib/'],
};
