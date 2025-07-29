import {AppRegistry} from 'react-native'

import {name as appName} from './app.json'
import App from './src/App'
import ChatApp from './src/ChatApp'

// Register main app
AppRegistry.registerComponent(appName, () => App)

// Register chat component for sandbox usage
AppRegistry.registerComponent('ChatApp', () => ChatApp)
