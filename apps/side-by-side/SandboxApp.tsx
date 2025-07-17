import React, {useCallback, useRef, useState} from 'react'
import {
  ColorValue,
  FlatList,
  SafeAreaView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native'

declare global {
  var postMessage: (message: object) => void
  var setOnMessage: (handler: (payload: object) => void) => void
}

type AppProps = {
  sourceName: string
  targetName: string
  backgroundColor: ColorValue
}

function App({sourceName, backgroundColor}: AppProps) {
  const [counter, setCounter] = useState<number>(0)
  const [targetInput, setTargetInput] = useState<string>(
    `Some payload from ${sourceName}`
  )

  const [items, setItems] = useState<string[]>([])
  const flatListRef = useRef<FlatList>(null)

  const addItem = (newItem: string) => {
    setItems(prev => [...prev, newItem])

    setTimeout(() => {
      flatListRef.current?.scrollToEnd({animated: true})
    }, 100)
  }

  const onMessage = useCallback((payload: unknown) => {
    console.log('onMessage', payload)
    addItem(JSON.stringify(payload))
  }, [])

  const sendInput = () => {
    setCounter(c => c + 1)
    globalThis.postMessage({
      data: targetInput,
      date: new Date(),
      origin: sourceName,
      counter,
    })
  }

  const panic = () => (globalThis as any).panic()

  globalThis.setOnMessage(onMessage)

  return (
    <SafeAreaView style={[styles.safeRoot, {backgroundColor}]}>
      <View style={styles.container}>
        <Text>Payload to send:</Text>
        <TextInput
          style={styles.input}
          placeholder="Payload to send to target runtime..."
          value={targetInput}
          onChangeText={setTargetInput}
        />
        <TouchableOpacity style={styles.button} onPress={sendInput}>
          <Text>Send Data</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.crash} onPress={panic}>
          <Text>Crash TypeError</Text>
        </TouchableOpacity>

        <View style={styles.listContainer}>
          <FlatList
            style={styles.list}
            ref={flatListRef}
            data={items}
            keyExtractor={(item, index) => index.toString()}
            renderItem={({item}) => (
              <View style={styles.item}>
                <Text>{item}</Text>
              </View>
            )}
          />
        </View>
      </View>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  safeRoot: {
    flex: 1,
    width: '100%',
  },
  container: {
    flex: 1,
    paddingHorizontal: 5,
  },
  listContainer: {
    flex: 1,
  },
  input: {
    borderWidth: 1,
    borderColor: '#888',
    borderRadius: 6,
    paddingHorizontal: 10,
    paddingVertical: 8,
    marginBottom: 12,
    fontSize: 16,
    width: '100%',
  },
  button: {
    borderWidth: 1,
    borderColor: '#007AFF',
    borderRadius: 6,
    paddingVertical: 10,
    paddingHorizontal: 12,
    alignItems: 'center',
    marginBottom: 12,
    backgroundColor: '#e6f0ff',
  },
  crash: {
    borderWidth: 1,
    borderColor: '#ff9b9b',
    borderRadius: 6,
    paddingVertical: 10,
    paddingHorizontal: 12,
    alignItems: 'center',
    marginBottom: 12,
    backgroundColor: '#e6f0ff',
  },
  buttonText: {
    color: '#007AFF',
    fontWeight: '600',
    fontSize: 16,
  },
  list: {
    flex: 1,
  },
  item: {
    padding: 5,
    borderBottomWidth: 1,
    borderBottomColor: '#ccc',
  },
})

export default App
