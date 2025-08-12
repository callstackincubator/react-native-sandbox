/** @type {import('jest').Config} */
module.exports = {
  projects: [
    '<rootDir>/apps/*/jest.config.js', // This will find all jest.config.js files in app directories
  ],
  // Common settings for all projects
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@react-native-community|@callstack/react-native-sandbox|react-native-toast-message|react-native-reanimated)/)',
  ],
}
