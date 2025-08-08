/* eslint no-undef: "off" */

// Common mocks for all apps
jest.mock('@callstack/react-native-sandbox', () => 'View')
jest.mock('react-native-toast-message', () => 'Text')

// Setup react-native-reanimated for testing
require('react-native-reanimated').setUpTests()
