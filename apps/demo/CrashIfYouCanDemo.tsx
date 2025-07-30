import React from 'react'
import {Button, NativeModules, ScrollView, StyleSheet, View} from 'react-native'

export default function CrashIfYouCanDemo() {
  const triggerCrash = () => {
    // @ts-ignore
    global.nonExistentMethod() // Should crash the app
  }

  const overwriteGlobal = () => {
    // Overwrite console.log to something harmful
    console.log = () => {
      throw new Error('console.log has been hijacked!')
    }
    console.log('This will now throw') // This will crash or break logs
  }

  const accessBlockedTurboModule = () => {
    const FileReaderModule = NativeModules.FileReaderModule
    FileReaderModule.readAsText('/some/file.txt')
      .then((text: string) => console.log(text))
      .catch((err: any) => console.log(err.message))
  }

  const infiniteLoop = () => {
    while (true) {}
  }

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Button title="1. Crash App (undefined global)" onPress={triggerCrash} />
      <View style={styles.spacer} />
      <Button
        title="2. Overwrite Global (console.log)"
        onPress={overwriteGlobal}
      />
      <View style={styles.spacer} />
      <Button
        title="3. Access Blocked TurboModule"
        onPress={accessBlockedTurboModule}
      />
      <View style={styles.spacer} />
      <Button title="4. Infinite Loop" onPress={infiniteLoop} />
      <View style={styles.bottom} />
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: {
    padding: 16,
    justifyContent: 'center',
  },
  spacer: {
    height: 16,
  },
  bottom: {
    height: 36,
  },
})
