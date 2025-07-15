module.exports = {
  root: true,
  extends: '@react-native',
  ignorePatterns: [
    '**/*.eslintrc.js',
    '**/*.config.js',
    'packages/examples/*/*.js', // React Native entry points don't need linting
  ],
};
