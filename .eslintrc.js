module.exports = {
  root: true,
  extends: ['@react-native-community', 'prettier'],
  plugins: ['prettier'],
  rules: {
    'prettier/prettier': 'warn',
  },
  overrides: [
    {
      // TypeScript method overloads (e.g. AppstackSDK.configure) trip the base
      // rule, which does not understand overload signatures. The TS-aware
      // variant handles them correctly.
      files: ['*.ts', '*.tsx'],
      rules: {
        'no-dupe-class-members': 'off',
        '@typescript-eslint/no-dupe-class-members': 'error',
      },
    },
  ],
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
