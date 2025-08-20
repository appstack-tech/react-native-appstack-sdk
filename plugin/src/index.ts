import * as fs from 'fs';
import * as path from 'path';

const pkg = require('../../package.json');

// Try to import @expo/config-plugins, but provide fallback if not available
let ConfigPlugin: any;
let createRunOncePlugin: any;
let withDangerousMod: any;

try {
  const configPlugins = require('@expo/config-plugins');
  ConfigPlugin = configPlugins.ConfigPlugin;
  createRunOncePlugin = configPlugins.createRunOncePlugin;
  withDangerousMod = configPlugins.withDangerousMod;
} catch (error) {
  console.warn('@expo/config-plugins not available, using fallback plugin implementation');
}

/**
 * Fallback plugin function that modifies Android files directly
 */
const withAppstackSDKFallback = (config: any) => {
  try {
    const projectRoot = config.projectRoot || config.modRequest?.projectRoot || process.cwd();
    
    // Add to settings.gradle
    const settingsGradlePath = path.join(projectRoot, 'android/settings.gradle');
    if (fs.existsSync(settingsGradlePath)) {
      let settingsGradleContents = fs.readFileSync(settingsGradlePath, 'utf8');
      
      const includeStatement = `include ':react-native-appstack-sdk'
project(':react-native-appstack-sdk').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-appstack-sdk/android/sdk')`;
      
      if (!settingsGradleContents.includes(':react-native-appstack-sdk')) {
        settingsGradleContents += '\n' + includeStatement + '\n';
        fs.writeFileSync(settingsGradlePath, settingsGradleContents);
      }
    }

    // Add to app/build.gradle
    const appBuildGradlePath = path.join(projectRoot, 'android/app/build.gradle');
    if (fs.existsSync(appBuildGradlePath)) {
      let buildGradleContents = fs.readFileSync(appBuildGradlePath, 'utf8');
      const dependency = "    implementation project(':react-native-appstack-sdk')";
      
      if (!buildGradleContents.includes(dependency)) {
        // Find dependencies section and add our dependency
        const dependenciesMatch = buildGradleContents.match(/(dependencies\s*{[^}]*)/s);
        if (dependenciesMatch) {
          buildGradleContents = buildGradleContents.replace(
            dependenciesMatch[0],
            dependenciesMatch[0] + '\n' + dependency
          );
          fs.writeFileSync(appBuildGradlePath, buildGradleContents);
        }
      }
    }
  } catch (error) {
    console.warn('Failed to modify Android files:', error);
  }

  return config;
};

/**
 * Full-featured plugin using @expo/config-plugins
 */
const withAppstackSDKFull = (config: any) => {
  if (!withDangerousMod) {
    return withAppstackSDKFallback(config);
  }

  return withDangerousMod(config, [
    'android',
    async (config: any) => {
      const projectRoot = config.modRequest.projectRoot;
      
      // Add to settings.gradle
      const settingsGradlePath = path.join(projectRoot, 'android/settings.gradle');
      if (fs.existsSync(settingsGradlePath)) {
        let settingsGradleContents = fs.readFileSync(settingsGradlePath, 'utf8');
        
        const includeStatement = `include ':react-native-appstack-sdk'
project(':react-native-appstack-sdk').projectDir = new File(rootProject.projectDir, '../node_modules/react-native-appstack-sdk/android/sdk')`;
        
        if (!settingsGradleContents.includes(':react-native-appstack-sdk')) {
          settingsGradleContents += '\n' + includeStatement + '\n';
          fs.writeFileSync(settingsGradlePath, settingsGradleContents);
        }
      }

      // Add to app/build.gradle
      const appBuildGradlePath = path.join(projectRoot, 'android/app/build.gradle');
      if (fs.existsSync(appBuildGradlePath)) {
        let buildGradleContents = fs.readFileSync(appBuildGradlePath, 'utf8');
        const dependency = "    implementation project(':react-native-appstack-sdk')";
        
        if (!buildGradleContents.includes(dependency)) {
          // Find dependencies section and add our dependency
          const dependenciesMatch = buildGradleContents.match(/(dependencies\s*{[^}]*)/s);
          if (dependenciesMatch) {
            buildGradleContents = buildGradleContents.replace(
              dependenciesMatch[0],
              dependenciesMatch[0] + '\n' + dependency
            );
            fs.writeFileSync(appBuildGradlePath, buildGradleContents);
          }
        }
      }

      return config;
    },
  ]);
};

/**
 * Main plugin function
 */
const withAppstackSDK = (config: any) => {
  // Apply Android modifications
  config = withAppstackSDKFull(config);
  return config;
};

// Export the plugin with fallback support
const plugin = createRunOncePlugin ? createRunOncePlugin(withAppstackSDK, pkg.name, pkg.version) : withAppstackSDK;
export default plugin;
