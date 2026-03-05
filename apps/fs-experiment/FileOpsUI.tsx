import AsyncStorage from '@react-native-async-storage/async-storage'
import React, {useId, useState} from 'react'
import {
  InputAccessoryView,
  Keyboard,
  Platform,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  useColorScheme,
  View,
} from 'react-native'
import {Dirs, FileSystem} from 'react-native-file-access'
import RNFS from 'react-native-fs'

const MODULES = [
  {key: 'rnfs', label: 'RNFS'},
  {key: 'file-access', label: 'file-access'},
  {key: 'async-storage', label: 'async-storage'},
] as const
type Module = (typeof MODULES)[number]['key']

interface FileOpsUIProps {
  accentColor?: string
}

export default function FileOpsUI({accentColor}: FileOpsUIProps) {
  const isDarkMode = useColorScheme() === 'dark'
  const [module, setModule] = useState<Module>('rnfs')
  const [target, setTarget] = useState('secret')
  const [text, setText] = useState('')
  const [status, setStatus] = useState('Ready')
  const accessoryId = useId()

  const theme = {
    bg: isDarkMode ? '#000' : '#fff',
    surface: isDarkMode ? '#1c1c1e' : '#f2f2f7',
    text: isDarkMode ? '#fff' : '#000',
    textSec: isDarkMode ? '#8e8e93' : '#6c6c70',
    border: isDarkMode ? '#38383a' : '#d1d1d6',
    accent: accentColor ?? '#007aff',
    green: '#34c759',
    red: '#ff3b30',
    segBg: isDarkMode ? '#2c2c2e' : '#e8e8ed',
    segActive: isDarkMode ? '#3a3a3c' : '#fff',
  }

  const isStorage = module === 'async-storage'

  const getPath = () => {
    switch (module) {
      case 'rnfs':
        return `${RNFS.DocumentDirectoryPath}/${target}`
      case 'file-access':
        return `${Dirs.DocumentDir}/${target}`
      default:
        return target
    }
  }

  const onWrite = async () => {
    try {
      setStatus('Writing...')
      switch (module) {
        case 'rnfs':
          await RNFS.writeFile(getPath(), text, 'utf8')
          break
        case 'file-access':
          await FileSystem.writeFile(getPath(), text)
          break
        case 'async-storage':
          await AsyncStorage.setItem(target, text)
          break
      }
      setStatus(`Wrote: "${text}"`)
    } catch (e) {
      setStatus(`Error: ${(e as Error).message}`)
    }
  }

  const onRead = async () => {
    try {
      setStatus('Reading...')
      let content: string
      switch (module) {
        case 'rnfs':
          content = await RNFS.readFile(getPath(), 'utf8')
          break
        case 'file-access':
          content = await FileSystem.readFile(getPath())
          break
        case 'async-storage': {
          const val = await AsyncStorage.getItem(target)
          content = val ?? ''
          if (!val) {
            setStatus(`Key "${target}" not found`)
            return
          }
          break
        }
      }
      setText(content)
      setStatus(`Read: "${content}"`)
    } catch (e) {
      setStatus(`Error: ${(e as Error).message}`)
    }
  }

  const displayPath = isStorage ? `key: "${target}"` : `Documents/${target}`

  const statusColor = () => {
    if (status.includes('BREACH') || status.includes('Error')) return theme.red
    if (status.includes('Wrote') || status.includes('Read:')) return theme.green
    return theme.textSec
  }

  return (
    <View style={[styles.root, {backgroundColor: theme.bg}]}>
      <View style={[styles.segmented, {backgroundColor: theme.segBg}]}>
        {MODULES.map(m => {
          const active = m.key === module
          return (
            <TouchableOpacity
              key={m.key}
              style={[
                styles.segItem,
                active && [
                  styles.segItemActive,
                  {backgroundColor: theme.segActive},
                ],
              ]}
              onPress={() => setModule(m.key)}>
              <Text
                style={[
                  styles.segText,
                  {color: active ? theme.accent : theme.textSec},
                  active && styles.segTextActive,
                ]}
                numberOfLines={1}>
                {m.label}
              </Text>
            </TouchableOpacity>
          )
        })}
      </View>

      <TextInput
        style={[
          styles.targetInput,
          {
            color: theme.text,
            backgroundColor: theme.surface,
            borderColor: theme.border,
          },
        ]}
        value={target}
        onChangeText={setTarget}
        placeholder={isStorage ? 'Storage key...' : 'Filename...'}
        placeholderTextColor={theme.textSec}
        autoCapitalize="none"
        autoCorrect={false}
        returnKeyType="done"
        blurOnSubmit
        inputAccessoryViewID={accessoryId}
      />

      <TextInput
        style={[
          styles.contentInput,
          {
            color: theme.text,
            backgroundColor: theme.surface,
            borderColor: theme.border,
          },
        ]}
        value={text}
        onChangeText={setText}
        placeholder="Content..."
        placeholderTextColor={theme.textSec}
        multiline
        numberOfLines={3}
        inputAccessoryViewID={accessoryId}
      />

      <View style={styles.buttonRow}>
        <TouchableOpacity
          style={[styles.btn, {backgroundColor: theme.accent}]}
          onPress={onWrite}>
          <Text style={styles.btnText}>Write</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.btn, {backgroundColor: theme.green}]}
          onPress={onRead}>
          <Text style={styles.btnText}>Read</Text>
        </TouchableOpacity>
      </View>

      <Text style={[styles.status, {color: statusColor()}]} numberOfLines={2}>
        {status}
      </Text>
      <Text style={[styles.path, {color: theme.textSec}]}>{displayPath}</Text>

      {Platform.OS === 'ios' && (
        <InputAccessoryView nativeID={accessoryId}>
          <View
            style={[
              styles.accessory,
              {backgroundColor: theme.surface, borderTopColor: theme.border},
            ]}>
            <TouchableOpacity onPress={Keyboard.dismiss}>
              <Text style={[styles.accessoryBtn, {color: theme.accent}]}>
                Done
              </Text>
            </TouchableOpacity>
          </View>
        </InputAccessoryView>
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    padding: 12,
  },
  segmented: {
    flexDirection: 'row',
    borderRadius: 8,
    padding: 2,
    marginBottom: 8,
  },
  segItem: {
    flex: 1,
    paddingVertical: 6,
    alignItems: 'center',
    borderRadius: 6,
  },
  segItemActive: {
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: {width: 0, height: 1},
        shadowOpacity: 0.12,
        shadowRadius: 2,
      },
      android: {elevation: 1},
    }),
  },
  segText: {
    fontSize: 11,
    fontWeight: '500',
  },
  segTextActive: {
    fontWeight: '600',
  },
  targetInput: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 8,
    fontSize: 13,
    marginBottom: 6,
  },
  contentInput: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 10,
    minHeight: 64,
    maxHeight: 80,
    textAlignVertical: 'top',
    fontSize: 14,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 10,
    marginVertical: 8,
  },
  btn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center',
  },
  btnText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 14,
  },
  status: {
    fontSize: 12,
    fontStyle: 'italic',
  },
  path: {
    fontSize: 10,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    marginTop: 2,
    opacity: 0.7,
  },
  accessory: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  accessoryBtn: {
    fontSize: 16,
    fontWeight: '600',
  },
})
