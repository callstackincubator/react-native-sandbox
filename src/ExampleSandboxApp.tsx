import React, {useCallback, useEffect, useRef, useState} from 'react';
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

// TODO remove it
// use injected postMessage and useOnMessage host functions
// it's impossible to pass it with initial props
import MultiReactMediatorModule from '../specs/NativeMultiReactMediator'

type AppProps = {
  contextId: string, // remove once postMessage and useOnMessage installed to globals
  sourceName: string,
  targetName: string,
  backgroundColor: ColorValue
}

function App({contextId, sourceName, backgroundColor}: AppProps): React.JSX.Element {
  const [counter, setCounter] = useState<number>(0);
  const [targetInput, setTargetInput] = useState<string>(`Some payload from ${sourceName}`);

  const [items, setItems] = useState<string[]>([]);
  const flatListRef = useRef<FlatList>(null);

  const addItem = (newItem: string) => {
    setItems(prev => [...prev, newItem]);

    setTimeout(() => {
      flatListRef.current?.scrollToEnd({ animated: true });
    }, 100);
  };

  const onMessage = useCallback((payload: unknown) => addItem(JSON.stringify(payload)), []);

  // TODO do't expose `host_${contextId}` explicitly
  // ideally it should looks something like 
  useEffect(() => {
    MultiReactMediatorModule.registerRuntime(`host_${contextId}`, onMessage);
  }, []);

  const sendInput = () => {
    setCounter((c) => c + 1);
    (globalThis as any).postMessage(
      { data: targetInput, origin: sourceName, counter }, `${contextId}_host`
    );
  };

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