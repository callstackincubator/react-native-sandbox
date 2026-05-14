import {AppRegistry} from 'react-native'

import SandboxApp from './SandboxApp'
import SandboxAppConvention from './SandboxAppConvention'

AppRegistry.registerComponent('SandboxApp', () => SandboxApp)
AppRegistry.registerComponent(
  'SandboxAppConvention',
  () => SandboxAppConvention
)
