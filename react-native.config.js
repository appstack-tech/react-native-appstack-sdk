module.exports = {
  dependencies: {
    'react-native-appstack-sdk': {
      platforms: {
        android: {
          sourceDir: '../android/sdk',
          packageImportPath: 'import com.appstack.attribution.AppstackReactNativePackage;',
        },
        ios: {
          // iOS configuration is handled by the podspec
        },
      },
    },
  },
};
