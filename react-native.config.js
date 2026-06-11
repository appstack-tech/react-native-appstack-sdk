module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.appstack.reactnative.AppstackReactNativePackage;',
        // Must stay unqualified: since RN 0.84 (Expo SDK 56) the gradle plugin
        // expands the class name to the FQCN from packageImportPath itself, so a
        // fully-qualified instance gets the package prefix duplicated.
        packageInstance: 'new AppstackReactNativePackage()',
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
