import SandboxReactNativeView, {
  SandboxReactNativeViewRef,
} from '@callstack/react-native-sandbox'
import React, {useRef, useState} from 'react'
import {SafeAreaView, StyleSheet, Switch, Text, View} from 'react-native'
import Toast from 'react-native-toast-message'

interface CounterSandboxProps {
  sourceName: string
  backgroundColor: string
  targetOrigin: string
  isCommunicationEnabled: boolean
  onCommunicationToggle: (enabled: boolean) => void
  communicationLabel: string
}

function CounterSandboxView({
  sourceName,
  backgroundColor,
  targetOrigin,
  isCommunicationEnabled,
  onCommunicationToggle,
  communicationLabel,
}: CounterSandboxProps) {
  const sandboxRef = useRef<SandboxReactNativeViewRef>(null)

  const handleMessage = (msg: any) => {
    console.log(`Got message from ${sourceName}`, msg)

    Toast.show({
      type: 'info',
      text1: sourceName,
      text2: JSON.stringify(msg),
    })
  }

  const handleError = (error: any) => {
    const isFatal = error.isFatal
    const message = `Got ${isFatal ? 'fatal' : 'non-fatal'} error from ${sourceName}`
    console.warn(message, error)
    Toast.show({
      type: 'error',
      text1: message,
      text2: `${error.name}: ${error.message}`,
    })
    return false
  }

  return (
    <SafeAreaView style={{margin: 10, flex: 1}}>
      <View style={styles.communicationControl}>
        <Text>{communicationLabel}</Text>
        <Switch
          value={isCommunicationEnabled}
          onValueChange={onCommunicationToggle}
        />
      </View>
      <SandboxReactNativeView
        id={sourceName}
        ref={sandboxRef}
        jsBundleSource={'sandbox'}
        componentName={'CounterApp'}
        style={styles.sandboxView}
        initialProperties={{
          sourceName,
          backgroundColor,
          targetOrigin: targetOrigin,
        }}
        allowedOrigins={isCommunicationEnabled ? [targetOrigin] : []}
        onMessage={handleMessage}
        onError={handleError}
      />
    </SafeAreaView>
  )
}

export default function App() {
  const [allowAtoB, setAllowAtoB] = useState(false)
  const [allowBtoA, setAllowBtoA] = useState(false)

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text>Sandbox 2 sandbox direct communication</Text>
      </View>

      <View style={styles.sandboxContainer}>
        <CounterSandboxView
          sourceName="A"
          backgroundColor="#CCFFCC"
          targetOrigin="B"
          isCommunicationEnabled={allowAtoB}
          onCommunicationToggle={setAllowAtoB}
          communicationLabel="A → B"
        />
        <CounterSandboxView
          sourceName="B"
          backgroundColor="#CCCCFF"
          targetOrigin="A"
          isCommunicationEnabled={allowBtoA}
          onCommunicationToggle={setAllowBtoA}
          communicationLabel="B → A"
        />
      </View>

      <Toast />
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    padding: 20,
    alignItems: 'center',
  },
  sandboxContainer: {
    flex: 1,
    flexDirection: 'row',
  },
  control: {
    alignItems: 'center',
    margin: 5,
  },
  communicationControl: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 10,
    margin: 5,
  },
  sandboxView: {
    flex: 1,
    padding: 20,
  },
})
