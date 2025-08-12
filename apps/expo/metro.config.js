const {getDefaultConfig} = require('expo/metro-config')
const path = require('path')

const projectRoot = __dirname
const workspaceRoot = path.resolve(projectRoot, '../..')

/**
 * Metro configuration for Expo
 * https://docs.expo.dev/guides/customizing-metro
 */
const config = getDefaultConfig(projectRoot)

// Add workspace support for monorepo
config.watchFolders = [workspaceRoot]

// Configure resolver for workspace dependencies
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(workspaceRoot, 'node_modules'),
]

// Ensure proper resolution of workspace packages
config.resolver.disableHierarchicalLookup = true

module.exports = config
