import {AppRegistry, LogBox} from 'react-native'

// eslint-disable-next-line import/no-unresolved
import Sandbox from './Sandbox'

LogBox.uninstall()

AppRegistry.registerComponent('SandboxedDemo', () => Sandbox)
