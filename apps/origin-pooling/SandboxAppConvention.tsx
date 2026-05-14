/**
 * SandboxAppConvention — convention-based approach (no library dependency).
 *
 * Uses the __sandboxDelegateId prop directly with globalThis.postMessage
 * and globalThis.setOnMessage for per-surface routing. No import from
 * @callstack/react-native-sandbox needed.
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
  setOnMessage: (cb: (msg: unknown) => void, delegateId?: string) => void
}

type LogEntry = {dir: 'in' | 'out'; text: string; ts: number}

type Props = {
  __sandboxDelegateId?: string
}

export default function SandboxAppConvention({__sandboxDelegateId}: Props) {
  const [log, setLog] = useState<LogEntry[]>([])
  const instanceId = useRef(Math.random().toString(36).slice(2, 6)).current
  const seq = useRef(0)
  const logRef = useRef<ScrollView>(null)

  const addLog = (dir: 'in' | 'out', text: string) =>
    setLog(prev => [...prev.slice(-19), {dir, text, ts: Date.now()}])

  // Convention: spread __sandboxDelegateId into the payload for per-surface routing
  const send = React.useCallback(
    (msg: Record<string, unknown>, targetOrigin?: string) => {
      const payload =
        !targetOrigin && __sandboxDelegateId
          ? {...msg, __sandboxDelegateId}
          : msg
      globalThis.postMessage(payload, targetOrigin)
    },
    [__sandboxDelegateId]
  )

  useEffect(() => {
    send({type: 'rendered', instanceId})
    addLog('out', `rendered (${instanceId})`)
  }, [instanceId, send])

  // Convention: pass delegateId as 2nd arg for per-surface listener
  useEffect(() => {
    globalThis.setOnMessage((msg: unknown) => {
      const data = msg as Record<string, unknown>
      addLog('in', `from ${data.instanceId ?? '?'}: ${data.type}`)
    }, __sandboxDelegateId)
    return () => {
      globalThis.setOnMessage(() => {}, __sandboxDelegateId)
    }
  }, [__sandboxDelegateId])

  const sendHeartbeat = () => {
    const s = ++seq.current
    send({type: 'heartbeat', instanceId, seq: s})
    addLog('out', `heartbeat seq=${s}`)
  }

  const pingAlpha = () => {
    send({type: 'ping', instanceId}, 'alpha')
    addLog('out', 'ping → alpha')
  }

  const pingBeta = () => {
    send({type: 'ping', instanceId}, 'beta')
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
      <Text style={styles.approach}>Convention (no import)</Text>
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
  approach: {color: '#888', fontSize: 9, marginBottom: 4},
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
