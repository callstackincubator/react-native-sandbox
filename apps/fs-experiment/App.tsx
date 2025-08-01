import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React, {useState} from 'react'
import {
  Platform,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  useColorScheme,
  View,
} from 'react-native'
// File system imports
import RNFS from 'react-native-fs'

const SHARED_FILE_PATH = `${RNFS.DocumentDirectoryPath}/shared_test_file.txt`

function App(): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark'
  const [textContent, setTextContent] = useState<string>('')
  const [status, setStatus] = useState<string>('Ready')

  const theme = {
    background: isDarkMode ? '#000000' : '#ffffff',
    surface: isDarkMode ? '#1c1c1e' : '#f2f2f7',
    primary: isDarkMode ? '#007aff' : '#007aff',
    secondary: isDarkMode ? '#34c759' : '#34c759',
    text: isDarkMode ? '#ffffff' : '#000000',
    textSecondary: isDarkMode ? '#8e8e93' : '#3c3c43',
    border: isDarkMode ? '#38383a' : '#c6c6c8',
    success: '#34c759',
    error: '#ff3b30',
  }

  const writeFile = async () => {
    try {
      setStatus('Writing file...')
      await RNFS.writeFile(SHARED_FILE_PATH, textContent, 'utf8')
      setStatus(`Successfully wrote: "${textContent}"`)
    } catch (error) {
      setStatus(`Write error: ${(error as Error).message}`)
    }
  }

  const readFile = async () => {
    try {
      setStatus('Reading file...')
      const content = await RNFS.readFile(SHARED_FILE_PATH, 'utf8')
      setTextContent(content)
      setStatus(`Successfully read: "${content}"`)
    } catch (error) {
      setStatus(`Read error: ${(error as Error).message}`)
    }
  }

  const getStatusStyle = () => {
    if (status.includes('error')) {
      return {color: theme.error}
    }
    if (status.includes('Successfully')) {
      return {color: theme.success}
    }
    return {color: theme.textSecondary}
  }

  return (
    <SafeAreaView
      style={[styles.container, {backgroundColor: theme.background}]}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={theme.background}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={{backgroundColor: theme.background}}
        showsVerticalScrollIndicator={false}>
        {/* Header */}
        <View style={[styles.header, {backgroundColor: theme.surface}]}>
          <Text style={[styles.headerTitle, {color: theme.text}]}>
            File System Sandbox Demo
          </Text>
          <Text style={[styles.headerSubtitle, {color: theme.textSecondary}]}>
            Multi-instance file system access testing
          </Text>
        </View>

        <View style={styles.content}>
          {/* Host Application Section */}
          <View
            style={[
              styles.card,
              {backgroundColor: theme.surface, borderColor: theme.border},
            ]}>
            <View style={styles.cardHeader}>
              <Text style={[styles.cardTitle, {color: theme.text}]}>
                Host Application
              </Text>
              <View style={[styles.badge, {backgroundColor: theme.primary}]}>
                <Text style={styles.badgeText}>Primary</Text>
              </View>
            </View>

            <TextInput
              style={[
                styles.textInput,
                {
                  color: theme.text,
                  backgroundColor: theme.background,
                  borderColor: theme.border,
                },
              ]}
              value={textContent}
              onChangeText={setTextContent}
              placeholder="Enter text to write to file..."
              placeholderTextColor={theme.textSecondary}
              multiline
            />

            <View style={styles.buttonGroup}>
              <TouchableOpacity
                style={[
                  styles.button,
                  styles.primaryButton,
                  {backgroundColor: theme.primary},
                ]}
                onPress={writeFile}>
                <Text style={styles.buttonText}>Write File</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[
                  styles.button,
                  styles.secondaryButton,
                  {backgroundColor: theme.secondary},
                ]}
                onPress={readFile}>
                <Text style={styles.buttonText}>Read File</Text>
              </TouchableOpacity>
            </View>

            <View
              style={[
                styles.statusContainer,
                {backgroundColor: theme.background},
              ]}>
              <Text style={[styles.statusLabel, {color: theme.textSecondary}]}>
                Status:
              </Text>
              <Text style={[styles.statusText, getStatusStyle()]}>
                {status}
              </Text>
            </View>

            <Text style={[styles.pathText, {color: theme.textSecondary}]}>
              {SHARED_FILE_PATH}
            </Text>
          </View>

          {/* Sandbox Sections */}
          <View
            style={[
              styles.card,
              {backgroundColor: theme.surface, borderColor: theme.border},
            ]}>
            <View style={styles.cardHeader}>
              <Text style={[styles.cardTitle, {color: theme.text}]}>
                Sandbox: react-native-fs
              </Text>
              <View style={[styles.badge, styles.sandboxBadge]}>
                <Text style={styles.badgeText}>Sandbox</Text>
              </View>
            </View>
            <SandboxReactNativeView
              style={[
                styles.sandbox,
                {backgroundColor: theme.background, borderColor: theme.border},
              ]}
              componentName={'AppFS'}
              jsBundleSource="sandbox-fs"
              allowedTurboModules={['RNFSManager', 'FileReaderModule']}
              onMessage={message => {
                console.log('Host received message from sandbox:', message)
              }}
              onError={error => {
                console.log('Host received error from sandbox:', error)
              }}
            />
          </View>

          <View
            style={[
              styles.card,
              {backgroundColor: theme.surface, borderColor: theme.border},
            ]}>
            <View style={styles.cardHeader}>
              <Text style={[styles.cardTitle, {color: theme.text}]}>
                Sandbox: react-native-file-access
              </Text>
              <View style={[styles.badge, styles.sandboxBadge]}>
                <Text style={styles.badgeText}>Sandbox</Text>
              </View>
            </View>
            <SandboxReactNativeView
              style={[
                styles.sandbox,
                {backgroundColor: theme.background, borderColor: theme.border},
              ]}
              componentName={'AppFileAccess'}
              allowedTurboModules={['FileAccess']}
              jsBundleSource="sandbox-file-access"
              onMessage={message => {
                console.log('Host received message from sandbox:', message)
              }}
              onError={error => {
                console.log('Host received error from sandbox:', error)
              }}
            />
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 20,
    paddingVertical: 24,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: {width: 0, height: 1},
        shadowOpacity: 0.1,
        shadowRadius: 4,
      },
      android: {
        elevation: 2,
      },
    }),
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: '700',
    letterSpacing: -0.5,
  },
  headerSubtitle: {
    fontSize: 16,
    marginTop: 4,
    fontWeight: '400',
  },
  content: {
    padding: 16,
  },
  card: {
    marginBottom: 20,
    borderRadius: 12,
    padding: 20,
    borderWidth: 1,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: {width: 0, height: 2},
        shadowOpacity: 0.1,
        shadowRadius: 8,
      },
      android: {
        elevation: 3,
      },
    }),
  },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '600',
    flex: 1,
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  badgeText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: '600',
    textTransform: 'uppercase',
  },
  sandboxBadge: {
    backgroundColor: '#ff6b35',
  },
  textInput: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 16,
    marginBottom: 16,
    minHeight: 100,
    textAlignVertical: 'top',
    fontSize: 16,
    lineHeight: 22,
  },
  buttonGroup: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 16,
  },
  button: {
    flex: 1,
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primaryButton: {
    // backgroundColor set dynamically
  },
  secondaryButton: {
    // backgroundColor set dynamically
  },
  buttonText: {
    color: '#ffffff',
    fontWeight: '600',
    fontSize: 16,
  },
  statusContainer: {
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
  },
  statusLabel: {
    fontSize: 14,
    fontWeight: '500',
    marginBottom: 4,
  },
  statusText: {
    fontSize: 14,
    fontStyle: 'italic',
    lineHeight: 20,
  },
  pathText: {
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    opacity: 0.8,
    lineHeight: 16,
  },
  sandbox: {
    height: 320,
    borderWidth: 1,
    borderRadius: 8,
  },
})

export default App
