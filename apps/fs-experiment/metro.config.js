const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config')
const path = require('path')
const fs = require('fs')

const projectRoot = __dirname
const workspaceRoot = path.resolve(projectRoot, '../..')

const appNodeModules = path.resolve(projectRoot, 'node_modules')
const rootNodeModules = path.resolve(workspaceRoot, 'node_modules')

// Pin react-native and all @react-native/* scoped packages so that both the
// main bundle and the harness test bundle resolve the same 0.82.1 version
// instead of accidentally picking up the monorepo root's 0.80.1 copy.
const extraNodeModules = {}

function pinRnScoped(dir) {
  const scopeDir = path.join(dir, '@react-native')
  if (fs.existsSync(scopeDir)) {
    for (const entry of fs.readdirSync(scopeDir)) {
      const key = `@react-native/${entry}`
      if (!extraNodeModules[key]) {
        extraNodeModules[key] = path.join(scopeDir, entry)
      }
    }
  }
}
pinRnScoped(appNodeModules)
pinRnScoped(rootNodeModules)

extraNodeModules['react-native'] = path.join(appNodeModules, 'react-native')
extraNodeModules['react'] = path.join(appNodeModules, 'react')

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = {
  watchFolders: [workspaceRoot],
  resolver: {
    nodeModulesPaths: [appNodeModules, rootNodeModules],
    extraNodeModules,
    disableHierarchicalLookup: true,
    unstable_enablePackageExports: true,
  },
  serializer: {},
  transformer: {
    getTransformOptions: async () => ({
      transform: {
        experimentalImportSupport: false,
        inlineRequires: true,
      },
    }),
  },
}

module.exports = mergeConfig(getDefaultConfig(projectRoot), config)
