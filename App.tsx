/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React, {useEffect, useRef, useState} from 'react';
import {
  FlatList,
  TextInput,
  Text,
  TouchableOpacity,
  View,
  StyleSheet,
  ColorValue,
  SafeAreaView
} from 'react-native';

import MultiReactMediatorModule from './specs/NativeMultiReactMediator'

type AppProps = {
  sourceName: string,
  targetName: string,
  backgroundColor: ColorValue
}

function App({sourceName, targetName, backgroundColor}: AppProps): React.JSX.Element {
  const [counter, setCounter] = useState<number>(0);
  const [runtimeName, setRuntimeName] = useState<string>(sourceName);
  const [targetInput, setTargetInput] = useState<string>(`Some payload from ${runtimeName}`);
  const [targetRuntimeName, setTargetRuntimeName] = useState<string>(targetName);

  const [items, setItems] = useState<string[]>([]);
  const flatListRef = useRef<FlatList>(null);

  const addItem = (newItem: string) => {
    setItems(prev => [...prev, newItem]);

    setTimeout(() => {
      flatListRef.current?.scrollToEnd({ animated: true });
    }, 100);
  };

  const onMessage = (payload: unknown) => {
    let payloadString = JSON.stringify(payload);
    console.log(`[${runtimeName}] onMessage`, payloadString);
    addItem(payloadString)
  };

  const registerRuntime = () => {
    MultiReactMediatorModule.registerRuntime(runtimeName, onMessage);
  };

  const sendInput = () => {
    setCounter((c) => c + 1);
    MultiReactMediatorModule.postMessage(
      targetRuntimeName,
      { data: targetInput, origin: runtimeName, counter }
    );
  };

  useEffect(() => {
    MultiReactMediatorModule.registerRuntime(runtimeName, onMessage);
  }, []);

  return (
    <SafeAreaView style={[styles.safeRoot, {backgroundColor}]}>
      <View style={styles.container}>
        <Text>Origin Instance (Runtime) Name:</Text>
        <TextInput
          style={styles.input}
          placeholder="Current runtime name..."
          value={runtimeName}
          onChangeText={setRuntimeName}
          editable={false}
        />
        <TouchableOpacity
          style={styles.button}
          onPress={registerRuntime}>
            <Text>Register Runtime</Text>
        </TouchableOpacity>

        <Text>Target Instance (Runtime) Name:</Text>
        <TextInput
          style={styles.input}
          placeholder="Target runtime name..."
          value={targetRuntimeName}
          onChangeText={setTargetRuntimeName}
        />
        <Text>Payload to send:</Text>
        <TextInput
          style={styles.input}
          placeholder="Payload to send to target runtime..."
          value={targetInput}
          onChangeText={setTargetInput}
        />
        <TouchableOpacity
          style={styles.button}
          onPress={sendInput}>
            <Text>Send Data</Text>
        </TouchableOpacity>

        <View style={{ flex: 1 }}>
          <FlatList
            style={styles.list}
            ref={flatListRef}
            data={items}
            keyExtractor={(item, index) => index.toString()}
            renderItem={({ item }) => (
              <View style={styles.item}>
                <Text>{item}</Text>
              </View>
            )}
          />
        </View>
        {/* <View style={{ height: 1, backgroundColor: 'gray' }} />
        <Text>Total Items: {items.length}</Text> */}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeRoot: {
    flex: 1,
    width: '100%'
  },
  container: {
    flex: 1,
    paddingHorizontal: 5
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
});

export default App;
