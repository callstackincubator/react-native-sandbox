import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React, {useState} from 'react'
import {SafeAreaView, StyleSheet, Text, View} from 'react-native'

import CrashIfYouCanDemo from './CrashIfYouCanDemo'

const DemoApp: React.FC = () => {
  const [lastError, setLastError] = useState<string | null>(null)

  return (
    <SafeAreaView style={styles.safeArea}>
      <View style={styles.container}>
        <View style={styles.column}>
          <Text style={styles.header}>Main App</Text>
          <CrashIfYouCanDemo />
        </View>
        <View style={[styles.column, styles.columnSandbox]}>
          <Text style={styles.header}>Sandboxed</Text>
          {lastError && <Text style={styles.errorText}>{lastError}</Text>}
          <SandboxReactNativeView
            style={styles.sandboxView}
            jsBundleSource={'sandbox'}
            componentName={'SandboxedDemo'}
            onError={error => {
              const message = `${error.isFatal ? '[fatal]' : '[warn]'} ${error.name}: ${error.message}`
              console.warn('Sandbox error:', message)
              setLastError(message)
              return false
            }}
          />
        </View>
      </View>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
  },
  container: {
    flex: 1,
    flexDirection: 'row',
    padding: 16,
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
  header: {
    fontWeight: 'bold',
    fontSize: 16,
    marginBottom: 8,
    textAlign: 'center',
  },
  sandboxView: {
    flex: 1,
  },
  errorText: {
    color: 'red',
    fontSize: 11,
    marginBottom: 4,
  },
})

export default DemoApp
