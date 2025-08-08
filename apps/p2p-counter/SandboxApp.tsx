import React, {useCallback, useEffect, useState} from 'react'
import {Button, StyleSheet, Text, View} from 'react-native'

type AppProps = {
  sourceName: string
  backgroundColor: string
  targetOrigin: string
}

function App({sourceName, backgroundColor, targetOrigin}: AppProps) {
  const [counterThis, setCounterThis] = useState(0)

  const incrementThis = () => {
    setCounterThis(prev => prev + 1)
    // No message sent to host or targetOrigin
  }

  const incrementThat = () => {
    // Send message directly to targetOrigin
    if (typeof globalThis.postMessage === 'function') {
      globalThis.postMessage(
        {
          type: 'counter_update',
          value: 1, // Increment by 1
          source: sourceName,
          counter: 'that',
        },
        targetOrigin
      )
    }
  }

  const onMessage = useCallback((payload: any) => {
    if (payload.type === 'counter_update') {
      setCounterThis(prev => prev + 1)
    }
  }, [])

  // Set up message handler
  useEffect(() => {
    if (typeof globalThis.setOnMessage === 'function') {
      globalThis.setOnMessage(onMessage)
    }
  }, [onMessage])

  return (
    <View style={[styles.container, {backgroundColor}]}>
      <Text style={styles.title}>Sandbox {sourceName}</Text>

      <View style={styles.counterContainer}>
        <View style={styles.counterBox}>
          <Text style={styles.counterValue}>{counterThis}</Text>
          <Button title="Increment This" onPress={incrementThis} />

          <View style={styles.buttonSpacer} />

          <Button title="Increment That" onPress={incrementThat} />
        </View>
      </View>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    justifyContent: 'center',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 30,
    color: '#333',
  },
  counterContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 30,
  },
  counterBox: {
    alignItems: 'center',
    padding: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.8)',
    borderRadius: 10,
    minWidth: 120,
  },
  counterLabel: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 10,
    color: '#333',
  },
  counterValue: {
    fontSize: 48,
    fontWeight: 'bold',
    marginBottom: 15,
    color: '#007AFF',
  },
  buttonSpacer: {
    height: 10,
  },
})

export default App
