const {getDefaultConfig} = require('expo/metro-config')
const path = require('path')

const projectRoot = __dirname
const workspaceRoot = path.resolve(projectRoot, '../..')

const config = getDefaultConfig(projectRoot)

// Monorepo: watch workspace root so Metro can resolve packages/react-native-sandbox
config.watchFolders = [workspaceRoot]

// Resolution order: app-local first, then workspace root.
// disableHierarchicalLookup prevents accidentally climbing up beyond workspaceRoot.
config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, 'node_modules'),
  path.resolve(workspaceRoot, 'node_modules'),
]
config.resolver.disableHierarchicalLookup = true

// Pin react and react-native to specific node_modules to avoid version
// mismatch when the workspace root has a different RN version (e.g. apps/demo
// uses 0.80.1 while we use 0.81.4).
// react is pinned to workspaceRoot because bun may hoist an older transitive
// version into apps/expo-demo/node_modules when deduplicating workspace deps.
config.resolver.extraNodeModules = {
  'react': path.resolve(workspaceRoot, 'node_modules/react'),
  'react-native': path.resolve(projectRoot, 'node_modules/react-native'),
  'react-dom': path.resolve(projectRoot, 'node_modules/react-dom'),
}

module.exports = config
