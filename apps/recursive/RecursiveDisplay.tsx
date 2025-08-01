import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React from 'react'
import {StyleSheet, Text, View} from 'react-native'

const MAX_DEPTH = 5

interface Props {
  depth: number
}

const colors = ['#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#00FFFF']

const RecursiveDisplay = ({depth}: Props) => {
  const color = colors[depth - 1] || '#FFFFFF'

  return (
    <View style={[styles.container, {borderColor: color}]}>
      <Text style={styles.text}>Depth: {depth}</Text>
      {depth < MAX_DEPTH ? (
        <SandboxReactNativeView
          style={styles.flex}
          componentName="RecursiveDisplay"
          initialProperties={{depth: depth + 1}}
        />
      ) : (
        <Text style={styles.text}>Max depth reached!</Text>
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderWidth: 5,
    padding: 10,
  },
  flex: {flex: 1},
  text: {color: 'white', textAlign: 'center', marginBottom: 10},
})

export default RecursiveDisplay
