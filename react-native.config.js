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
        // cmakeListsPath is intentionally omitted. The default,
        // android/build/generated/source/codegen/jni/CMakeLists.txt, is exactly what
        // codegen produces and what the app's generated autolinking CMake
        // add_subdirectory()s. It used to be set to null in an attempt to disable
        // codegen autolinking, which never worked: null is falsy, so the resolver fell
        // through to this same default. The actual gate was the absence of
        // codegenConfig.name in package.json.
      },
      ios: {
        // iOS configuration is handled by the podspec
      },
    },
  },
};
