const withExpoPlugin = config => {
  // Add the EXPO_MODULE environment variable to enable Expo support
  if (config.ios) {
    config.ios.podfileProperties = config.ios.podfileProperties || {}
    config.ios.podfileProperties['EXPO_MODULE'] = '1'
  }

  return config
}

module.exports = withExpoPlugin
