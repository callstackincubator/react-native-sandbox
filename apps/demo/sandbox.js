import {AppRegistry, LogBox} from 'react-native'

import CrashIfYouCanDemo from './CrashIfYouCanDemo'

LogBox.uninstall()

AppRegistry.registerComponent('CrashIfYouCanDemo', () => CrashIfYouCanDemo)
