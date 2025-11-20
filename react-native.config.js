module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.appstack.reactnative.AppstackReactNativePackage;',
        packageInstance: 'new com.appstack.reactnative.AppstackReactNativePackage()',
        // Disable CMake autolinking - native build is handled by build.gradle externalNativeBuild
        // This prevents autolinking from trying to include codegen before it's generated
        cmakeListsPath: null,
      },
      ios: {
        // iOS configuration is handled by the podspec
      },
    },
  },
};
