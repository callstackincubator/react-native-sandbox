import AsyncStorage from '@react-native-async-storage/async-storage'
import React, {useEffect} from 'react'
import {AppRegistry} from 'react-native'
import {Dirs, FileSystem} from 'react-native-file-access'

import FileOpsUI from './FileOpsUI'

/**
 * Handles test commands sent from the host via postMessage.
 * This enables cross-boundary isolation tests: the host writes data,
 * then asks the sandbox to read the same key/file to verify isolation.
 *
 * Commands:
 *   { cmd: 'write', module: 'file-access'|'async-storage', target, content }
 *   { cmd: 'read',  module: 'file-access'|'async-storage', target }
 *
 * Responses sent back via postMessage:
 *   { cmd, ok: true, result: string }
 *   { cmd, ok: false, error: string }
 */
function installTestCommandHandler() {
  if (typeof globalThis.setOnMessage !== 'function') return

  globalThis.setOnMessage(async msg => {
    if (!msg || typeof msg !== 'object' || !msg.cmd) return

    const {cmd, module, target, content, id} = msg

    const reply = data => {
      if (typeof globalThis.postMessage === 'function') {
        globalThis.postMessage({...data, id})
      }
    }

    try {
      if (cmd === 'write') {
        if (module === 'file-access') {
          await FileSystem.writeFile(`${Dirs.DocumentDir}/${target}`, content)
        } else if (module === 'async-storage') {
          await AsyncStorage.setItem(target, content)
        }
        reply({cmd: 'write', ok: true, result: content})
      } else if (cmd === 'read') {
        let result
        if (module === 'file-access') {
          result = await FileSystem.readFile(`${Dirs.DocumentDir}/${target}`)
        } else if (module === 'async-storage') {
          result = (await AsyncStorage.getItem(target)) ?? null
        }
        reply({cmd: 'read', ok: true, result})
      }
    } catch (e) {
      reply({cmd, ok: false, error: e.message})
    }
  })
}

function SandboxApp(props) {
  useEffect(() => {
    installTestCommandHandler()
    if (typeof globalThis.postMessage === 'function') {
      globalThis.postMessage({cmd: 'ready'})
    }
  }, [])

  return <FileOpsUI testIDPrefix="sandbox" {...props} />
}

AppRegistry.registerComponent('SandboxApp', () => SandboxApp)
