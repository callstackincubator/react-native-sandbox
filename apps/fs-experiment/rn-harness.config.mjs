import {
  androidEmulator,
  androidPlatform,
} from '@react-native-harness/platform-android'
import {
  applePlatform,
  appleSimulator,
} from '@react-native-harness/platform-apple'

const iosDevice = process.env.HARNESS_IOS_DEVICE ?? 'iPhone 16 Pro'
const iosVersion = process.env.HARNESS_IOS_VERSION ?? '18.4'
const androidDevice =
  process.env.HARNESS_ANDROID_DEVICE ?? 'Medium_Phone_API_35'

const config = {
  entryPoint: './index.js',
  appRegistryComponentName: 'MultInstance-FSExperiment',

  runners: [
    applePlatform({
      name: 'ios',
      device: appleSimulator(iosDevice, iosVersion),
      bundleId: 'org.reactjs.native.example.MultInstance-FSExperiment',
    }),
    androidPlatform({
      name: 'android',
      device: androidEmulator(androidDevice),
      bundleId: 'com.multinstance.fsexperiment',
    }),
  ],

  defaultRunner: 'ios',
  forwardClientLogs: true,
  resetEnvironmentBetweenTestFiles: true,
  disableViewFlattening: true,
}

export default config
