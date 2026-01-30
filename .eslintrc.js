module.exports = {
  root: true,
  extends: ['@react-native-community', 'prettier'],
  plugins: ['prettier'],
  rules: {
    'prettier/prettier': 'warn',
  },
  ignorePatterns: [
    'lib/',
    'node_modules/',
    'homepage-app/',
    'plugin/build/',
    '*.podspec',
    'android/',
    'ios/',
    'babel.config.js',
  ],
  parserOptions: {
    ecmaVersion: 2020,
    sourceType: 'module',
    ecmaFeatures: {
      jsx: true,
    },
  },
  env: {
    node: true,
    es6: true,
    jest: true,
  },
};
