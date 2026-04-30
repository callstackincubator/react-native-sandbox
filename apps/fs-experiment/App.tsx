import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React, {useState} from 'react'
import {
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Switch,
  Text,
  useColorScheme,
  View,
} from 'react-native'

import FileOpsUI from './FileOpsUI'

// iOS async-storage exposes two module names: the legacy bridge name
// (PlatformLocalStorage) and the TurboModule spec name (RNC_AsyncSQLiteDBStorage).
// Both must be allowed so the sandbox can access the real module when
// substitution is OFF, and so the substitution mapping works when ON.
const ASYNC_STORAGE_MODULES =
  Platform.OS === 'ios'
    ? ['RNC_AsyncSQLiteDBStorage', 'PlatformLocalStorage', 'RNCAsyncStorage']
    : ['RNCAsyncStorage']

const ALL_TURBO_MODULES =
  Platform.OS === 'ios'
    ? ['RNFSManager', 'FileAccess', ...ASYNC_STORAGE_MODULES]
    : ['FileAccess', ...ASYNC_STORAGE_MODULES]

const SANDBOXED_SUBSTITUTIONS: Record<string, string> = {
  ...(Platform.OS === 'ios' && {RNFSManager: 'SandboxedRNFSManager'}),
  FileAccess: 'SandboxedFileAccess',
  ...Object.fromEntries(
    ASYNC_STORAGE_MODULES.map(m => [m, 'SandboxedAsyncStorage'])
  ),
}

function App(): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark'
  const [useSubstitution, setUseSubstitution] = useState(false)
  const [sandboxReady, setSandboxReady] = useState(false)

  const theme = {
    bg: isDarkMode ? '#000' : '#fff',
    surface: isDarkMode ? '#1c1c1e' : '#f2f2f7',
    text: isDarkMode ? '#fff' : '#000',
    textSec: isDarkMode ? '#8e8e93' : '#6c6c70',
    border: isDarkMode ? '#38383a' : '#d1d1d6',
    blue: '#007aff',
    green: '#34c759',
    orange: '#ff9500',
  }

  return (
    <SafeAreaView style={[styles.root, {backgroundColor: theme.bg}]}>
      {sandboxReady && <View testID="sandbox-ready" style={styles.hidden} />}
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={theme.bg}
      />

      <ScrollView
        style={{flex: 1}}
        keyboardDismissMode="interactive"
        keyboardShouldPersistTaps="handled"
        automaticallyAdjustKeyboardInsets>
        {/* ===== HOST ===== */}
        <View style={[styles.section, {borderBottomColor: theme.border}]}>
          <View
            style={[styles.sectionHeader, {backgroundColor: theme.surface}]}>
            <Text style={[styles.sectionTitle, {color: theme.text}]}>
              Host App
            </Text>
            <View style={[styles.badge, {backgroundColor: theme.blue}]}>
              <Text style={styles.badgeText}>HOST</Text>
            </View>
          </View>

          <FileOpsUI accentColor={theme.blue} testIDPrefix="host" />
        </View>

        {/* ===== SANDBOX ===== */}
        <View style={styles.section}>
          <View
            style={[styles.sectionHeader, {backgroundColor: theme.surface}]}>
            <Text style={[styles.sectionTitle, {color: theme.text}]}>
              Sandbox
            </Text>
            <View style={[styles.badge, {backgroundColor: theme.orange}]}>
              <Text style={styles.badgeText}>SANDBOXED</Text>
            </View>
          </View>

          <View style={styles.switchBar}>
            <Pressable
              testID="substitution-switch"
              accessibilityLabel={
                useSubstitution ? 'substitution-on' : 'substitution-off'
              }
              style={styles.switchRow}
              onPress={() => setUseSubstitution(v => !v)}>
              <Text style={[styles.switchLabel, {color: theme.text}]}>
                Module substitution{' '}
                <Text style={{color: theme.textSec, fontSize: 12}}>
                  {useSubstitution ? '(safe)' : '(off)'}
                </Text>
              </Text>
              <Switch
                value={useSubstitution}
                onValueChange={setUseSubstitution}
                trackColor={{false: theme.border, true: theme.green}}
              />
            </Pressable>
          </View>

          <SandboxReactNativeView
            style={styles.sandboxView}
            origin="sandbox.fs-experiment.demo"
            componentName="SandboxApp"
            jsBundleSource="sandbox"
            allowedTurboModules={ALL_TURBO_MODULES}
            turboModuleSubstitutions={
              useSubstitution ? SANDBOXED_SUBSTITUTIONS : undefined
            }
            onMessage={msg => {
              if (msg.cmd === 'ready') setSandboxReady(true)
              console.log('Host received from sandbox:', msg)
            }}
            onError={err =>
              console.log('Host received error from sandbox:', err)
            }
          />
        </View>
      </ScrollView>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  hidden: {
    width: 0,
    height: 0,
  },
  section: {
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 10,
  },
  sectionTitle: {
    fontSize: 17,
    fontWeight: '700',
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 5,
  },
  badgeText: {
    color: '#fff',
    fontSize: 10,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  switchBar: {
    paddingHorizontal: 16,
    paddingVertical: 6,
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  switchLabel: {
    fontSize: 14,
    fontWeight: '500',
    flex: 1,
  },
  sandboxView: {
    height: 400,
    marginBottom: 8,
  },
})

export default App
