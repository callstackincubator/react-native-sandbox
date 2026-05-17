module.exports = {
  preset: 'react-native',
  transformIgnorePatterns: [
    'node_modules/(?!(react-native|@react-native|@react-native-community|@callstack/react-native-sandbox)/)',
  ],
  setupFilesAfterEnv: ['<rootDir>/../../jest.setup.js'],
}
