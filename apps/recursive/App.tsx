/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * Generated with the TypeScript template
 * https://github.com/react-native-community/react-native-template-typescript
 *
 * @format
 */

import SandboxReactNativeView from '@callstack/react-native-sandbox'
import {NewAppScreen} from '@react-native/new-app-screen'
import React from 'react'
import {ScrollView, StyleSheet, Text, useColorScheme, View} from 'react-native'

const MAX_DEPTH = 5

interface AppProps {
  depth?: number
}

const App = ({depth = 1}: AppProps) => {
  const isDarkMode = useColorScheme() === 'dark'

  const backgroundStyle = {
    backgroundColor: isDarkMode ? '#000000' : '#ffffff',
  }

  return (
    <View style={backgroundStyle}>
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}>
        <Text style={styles.scrollHint}>👇👇 Scroll to the bottom 👇👇</Text>

        <NewAppScreen templateFileName="App.tsx" />

        <View style={styles.recursiveSection}>
          {depth < MAX_DEPTH ? (
            <View style={styles.recursiveSandboxContainer}>
              <Text style={styles.recursiveSandboxTitle}>
                Next Level (Depth: {depth + 1})
              </Text>
              <SandboxReactNativeView
                style={styles.recursiveSandbox}
                jsBundleSource="index"
                componentName="App"
                initialProperties={{depth: depth + 1}}
                onMessage={(msg: any) => console.log('message', msg)}
                onError={(e: any) => console.error('error', e)}
              />
            </View>
          ) : (
            <View style={styles.maxDepthContainer}>
              <Text
                style={[
                  styles.maxDepthTitle,
                  {color: isDarkMode ? '#ffffff' : '#000000'},
                ]}>
                Max Depth Reached!
              </Text>
              <Text
                style={[
                  styles.maxDepthDescription,
                  {color: isDarkMode ? '#cccccc' : '#666666'},
                ]}>
                No more nested instances will be created. This demonstrates the
                full capability of nested React Native instances.
              </Text>
            </View>
          )}
        </View>
      </ScrollView>
    </View>
  )
}

const styles = StyleSheet.create({
  scrollHint: {
    padding: 20,
    textAlign: 'center',
    fontSize: 22,
    backgroundColor: '#f3f3f3',
  },
  recursiveSection: {
    paddingHorizontal: 24,
    backgroundColor: '#f3f3f3',
    paddingBottom: 24,
    marginTop: -34,
  },
  recursiveSandboxContainer: {
    height: 500,
    borderWidth: 1,
    borderColor: '#cccccc',
    borderRadius: 8,
    overflow: 'hidden',
  },
  recursiveSandboxTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    textAlign: 'center',
    padding: 12,
    backgroundColor: '#f8f9fa',
    color: '#000000',
  },
  recursiveSandbox: {
    flex: 1,
  },
  maxDepthContainer: {
    padding: 20,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e9ecef',
  },
  maxDepthTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  maxDepthDescription: {
    fontSize: 14,
    lineHeight: 20,
  },
})

export default App
