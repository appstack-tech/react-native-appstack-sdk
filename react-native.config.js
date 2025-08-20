module.exports = {
  dependencies: {
    'react-native-appstack-sdk': {
      platforms: {
        android: {
          sourceDir: '../android',
          packageImportPath: 'import com.appstack.reactnative.AppstackReactNativePackage;',
          packageInstance: 'new com.appstack.reactnative.AppstackReactNativePackage()',
        },
        ios: {
          // iOS configuration is handled by the podspec
        },
      },
    },
  },
};
