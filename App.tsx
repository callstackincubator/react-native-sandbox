/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import React, {useEffect, useState} from 'react';
import {
  TextInput,
  Text,
  TouchableOpacity,
  useColorScheme,
  View,
  StyleSheet
} from 'react-native';

import {
  Colors
} from 'react-native/Libraries/NewAppScreen';

import MultiReactMediatorModule from './specs/NativeMultiReactMediator'

function App({sourceName, targetName}: {sourceName: string, targetName: string}): React.JSX.Element {
  const backgroundStyle = {
    backgroundColor: useColorScheme() === 'dark' ? Colors.darker : Colors.lighter,
  };

  const [counter, setCounter] = useState<number>(0);
  const [runtimeName, setRuntimeName] = useState<string>(sourceName);
  const [targetInput, setTargetInput] = useState<string>(`Some payload from ${runtimeName}`);
  const [targetRuntimeName, setTargetRuntimeName] = useState<string>(targetName);

  const onMessage = (payload: unknown) => {
    console.log(`[${runtimeName}] got payload`, payload);
  };

  const registerRuntime = () => {
    MultiReactMediatorModule.registerRuntime(runtimeName, onMessage);
  };

  const sendInput = () => {
    setCounter((c) => c + 1);
    MultiReactMediatorModule.postMessage(targetRuntimeName, { data: targetInput, origin: runtimeName, counter });
  };

  useEffect(() => {
    MultiReactMediatorModule.registerRuntime(runtimeName, onMessage);
  }, []);

  return (
    <View style={[styles.container, backgroundStyle]}>
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

      <View style={{ height: 1, backgroundColor: 'gray' }} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    width: '100%',               // full screen width
    paddingVertical: '5%',       // vertical padding 5% of container height
    paddingHorizontal: 5,        // horizontal padding 5px
    backgroundColor: 'white',    // fallback background
    paddingTop: 80,
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
});

export default App;
