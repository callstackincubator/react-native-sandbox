import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React from 'react'
import {SafeAreaView, StyleSheet, Text, View} from 'react-native'
import Toast from 'react-native-toast-message'

import CrashIfYouCanDemo from './CrashIfYouCanDemo'

const SideBySideDemo: React.FC = () => {
  return (
    <SafeAreaView>
      <View style={styles.container}>
        <View style={styles.column}>
          <Text style={styles.header}>Main App</Text>
          <CrashIfYouCanDemo />
        </View>
        <View style={[styles.column, styles.columnSandbox]}>
          <Text style={styles.header}>Sandboxed</Text>
          <SandboxReactNativeView
            style={styles.sandboxView}
            jsBundleSource={'sandbox'}
            moduleName={'CrashIfYouCanDemo'}
            onError={error => {
              const message = `Got ${error.isFatal ? 'fatal' : 'non-fatal'} error from sandbox`
              console.warn(message, error)
              Toast.show({
                type: 'error',
                text1: message,
                text2: `${error.name}: ${error.message}`,
                visibilityTime: 5000,
              })
              return false
            }}
          />
        </View>
      </View>
      <Toast />
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    padding: 16,
    justifyContent: 'space-between',
  },
  columnSandbox: {
    borderWidth: 1,
    borderColor: '#8232ff',
    borderRadius: 4,
  },
  column: {
    flex: 1,
    padding: 8,
  },
  divider: {
    width: 1,
    backgroundColor: '#ccc',
  },
  header: {
    fontWeight: 'bold',
    fontSize: 16,
    marginBottom: 8,
    textAlign: 'center',
  },
  sandboxView: {
    flex: 1,
    padding: 30,
  },
})

export default SideBySideDemo
