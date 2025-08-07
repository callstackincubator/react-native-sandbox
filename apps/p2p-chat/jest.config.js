module.exports = {
  preset: 'react-native',
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@react-native-community|@callstack/react-native-sandbox|react-native-toast-message|react-native-reanimated)/)',
  ],
  setupFilesAfterEnv: ['<rootDir>/../../jest.setup.js'],
}
