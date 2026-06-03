/**
 * SandboxApp — runs INSIDE each sandbox.
 *
 * Uses globalThis.postMessage directly (broadcast fallback, no per-surface routing).
 * Provides buttons to ping alpha/beta origins and send heartbeats to the host.
 * Displays an internal log of incoming and outgoing messages.
 */
import React, {useEffect, useRef, useState} from 'react'
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'

declare const globalThis: {
  postMessage: (msg: unknown, targetOrigin?: string) => void
  setOnMessage: (cb: (msg: unknown) => void) => void
}

type LogEntry = {dir: 'in' | 'out'; text: string; ts: number}

export default function SandboxApp() {
  const [log, setLog] = useState<LogEntry[]>([])
  const instanceId = useRef(Math.random().toString(36).slice(2, 6)).current
  const seq = useRef(0)
  const logRef = useRef<ScrollView>(null)

  const addLog = (dir: 'in' | 'out', text: string) =>
    setLog(prev => [...prev.slice(-19), {dir, text, ts: Date.now()}])

  // Signal first render to host
  useEffect(() => {
    globalThis.postMessage({type: 'rendered', instanceId})
    addLog('out', `rendered (${instanceId})`)
  }, [instanceId])

  // Listen for incoming messages (pings from other origins)
  useEffect(() => {
    globalThis.setOnMessage((msg: unknown) => {
      const data = msg as Record<string, unknown>
      addLog('in', `from ${data.instanceId ?? '?'}: ${data.type}`)
    })
  }, [])

  const sendHeartbeat = () => {
    const s = ++seq.current
    globalThis.postMessage({type: 'heartbeat', instanceId, seq: s})
    addLog('out', `heartbeat seq=${s}`)
  }

  const pingAlpha = () => {
    globalThis.postMessage({type: 'ping', instanceId}, 'alpha')
    addLog('out', 'ping → alpha')
  }

  const pingBeta = () => {
    globalThis.postMessage({type: 'ping', instanceId}, 'beta')
    addLog('out', 'ping → beta')
  }

  const triggerError = () => {
    addLog('out', 'throwing uncaught error…')
    setTimeout(() => {
      throw new Error(`Boom from ${instanceId}`)
    }, 0)
  }

  return (
    <View style={styles.root}>
      <Text style={styles.title}>ID: {instanceId}</Text>
      <View style={styles.buttons}>
        <View style={styles.btnRow}>
          <TouchableOpacity style={styles.btnGreen} onPress={sendHeartbeat}>
            <Text style={styles.btnText}>Heartbeat</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.btnRed} onPress={triggerError}>
            <Text style={styles.btnText}>Error</Text>
          </TouchableOpacity>
        </View>
        <View style={styles.btnRow}>
          <TouchableOpacity style={styles.btnPurple} onPress={pingAlpha}>
            <Text style={styles.btnText}>Ping alpha</Text>
          </TouchableOpacity>
          <TouchableOpacity style={styles.btnOrange} onPress={pingBeta}>
            <Text style={styles.btnText}>Ping beta</Text>
          </TouchableOpacity>
        </View>
      </View>
      <ScrollView
        ref={logRef}
        style={styles.log}
        onContentSizeChange={() => logRef.current?.scrollToEnd()}>
        {log.map((e, i) => (
          <Text key={i} style={styles.logLine}>
            {e.dir === 'in' ? '← ' : '→ '}
            {e.text}
          </Text>
        ))}
      </ScrollView>
    </View>
  )
}

const styles = StyleSheet.create({
  root: {flex: 1, padding: 6, backgroundColor: '#1a1a2e'},
  title: {color: '#d3e945', fontWeight: '700', fontSize: 13},
  buttons: {gap: 4, marginBottom: 4},
  btnRow: {flexDirection: 'row', gap: 4},
  btnGreen: {
    backgroundColor: '#16c79a',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    flex: 1,
  },
  btnPurple: {
    backgroundColor: '#8232ff',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    flex: 1,
  },
  btnOrange: {
    backgroundColor: '#e67e22',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    flex: 1,
  },
  btnRed: {
    backgroundColor: '#e94560',
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    flex: 1,
  },
  btnText: {color: '#fff', fontSize: 10, fontWeight: '600'},
  log: {flex: 1},
  logLine: {color: '#16c79a', fontSize: 10, fontFamily: 'monospace'},
})
