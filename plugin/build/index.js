"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const fs = __importStar(require("fs"));
const path = __importStar(require("path"));
const pkg = require('../../package.json');
// Try to import @expo/config-plugins, but provide fallback if not available
let ConfigPlugin;
let createRunOncePlugin;
let withDangerousMod;
try {
    const configPlugins = require('@expo/config-plugins');
    ConfigPlugin = configPlugins.ConfigPlugin;
    createRunOncePlugin = configPlugins.createRunOncePlugin;
    withDangerousMod = configPlugins.withDangerousMod;
}
catch (error) {
    console.warn('@expo/config-plugins not available, using fallback plugin implementation');
}
/**
 * Fallback plugin function that modifies Android files directly
 */
const withAppstackSDKFallback = (config) => {
    var _a;
    try {
        const projectRoot = config.projectRoot || ((_a = config.modRequest) === null || _a === void 0 ? void 0 : _a.projectRoot) || process.cwd();
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
                    buildGradleContents = buildGradleContents.replace(dependenciesMatch[0], dependenciesMatch[0] + '\n' + dependency);
                    fs.writeFileSync(appBuildGradlePath, buildGradleContents);
                }
            }
        }
    }
    catch (error) {
        console.warn('Failed to modify Android files:', error);
    }
    return config;
};
/**
 * Full-featured plugin using @expo/config-plugins
 */
const withAppstackSDKFull = (config) => {
    if (!withDangerousMod) {
        return withAppstackSDKFallback(config);
    }
    return withDangerousMod(config, [
        'android',
        async (config) => {
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
                        buildGradleContents = buildGradleContents.replace(dependenciesMatch[0], dependenciesMatch[0] + '\n' + dependency);
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
const withAppstackSDK = (config) => {
    // Apply Android modifications
    config = withAppstackSDKFull(config);
    return config;
};
// Export the plugin with fallback support
const plugin = createRunOncePlugin ? createRunOncePlugin(withAppstackSDK, pkg.name, pkg.version) : withAppstackSDK;
exports.default = plugin;
