/**
 * Origin Pooling Demo
 *
 * Dynamically add/remove sandboxes under two shared origins (alpha, beta)
 * plus an isolated (no-origin) option. Same-origin sandboxes share a
 * ReactHost / Hermes VM; removing the last one triggers the idle TTL.
 *
 * Messaging is handled inside the sandbox widget via globalThis.postMessage.
 * The host only logs messages received via onMessage.
 */
import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React, {useCallback, useRef, useState} from 'react'
import {
  Button,
  Platform,
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  View,
} from 'react-native'

type SandboxEntry = {key: string; label: string; origin: string}
type LogEntry = {source: string; text: string; ts: number}

let nextId = 0

const ORIGIN_ALPHA = 'alpha'
const ORIGIN_BETA = 'beta'
const COLOR_ALPHA = '#8232ff'
const COLOR_BETA = '#e67e22'
const COLOR_ISOLATED = '#6c757d'

/** Alpha uses a function-based TTL (4 seconds) */
const ALPHA_TTL = () => 4000
/** Beta and isolated use a static TTL (2 seconds) */
const DEFAULT_TTL = 2000

export default function App() {
  const [sandboxes, setSandboxes] = useState<SandboxEntry[]>([])
  const [log, setLog] = useState<LogEntry[]>([])
  const logScrollRef = useRef<ScrollView>(null)

  const addLog = useCallback((source: string, text: string) => {
    setLog(prev => [...prev.slice(-49), {source, text, ts: Date.now()}])
  }, [])

  const addSandbox = useCallback((origin: string) => {
    const id = String(++nextId)
    setSandboxes(prev => [...prev, {key: id, label: `#${id}`, origin}])
  }, [])

  const removeSandbox = useCallback((key: string) => {
    setSandboxes(prev => prev.filter(s => s.key !== key))
  }, [])

  const clearLog = useCallback(() => setLog([]), [])

  const alphas = sandboxes.filter(s => s.origin === ORIGIN_ALPHA)
  const betas = sandboxes.filter(s => s.origin === ORIGIN_BETA)
  const isolated = sandboxes.filter(s => s.origin === '')

  return (
    <SafeAreaView style={styles.safe}>
      <Text style={styles.heading}>Origin Pooling Demo</Text>
      <Text style={styles.subtitle}>
        Same-origin sandboxes share a VM. Alpha: function-based TTL (4s). Beta:
        static TTL (2s).
      </Text>

      <View style={styles.controls}>
        <Button
          title="+ Alpha"
          color={COLOR_ALPHA}
          onPress={() => addSandbox(ORIGIN_ALPHA)}
        />
        <Button
          title="+ Beta"
          color={COLOR_BETA}
          onPress={() => addSandbox(ORIGIN_BETA)}
        />
        <Button
          title="+ Isolated"
          color={COLOR_ISOLATED}
          onPress={() => addSandbox('')}
        />
        <Button title="Clear Log" onPress={clearLog} />
      </View>

      {/* Alpha sandboxes */}
      <Text style={[styles.groupLabel, {color: COLOR_ALPHA}]}>
        {'origin="alpha"'} ({alphas.length})
      </Text>
      <ScrollView
        horizontal
        style={styles.cardRow}
        contentContainerStyle={styles.cardRowContent}>
        {alphas.map(sb => (
          <SandboxCard
            key={sb.key}
            entry={sb}
            color={COLOR_ALPHA}
            idleTTL={ALPHA_TTL}
            onRemove={() => removeSandbox(sb.key)}
            onMessage={data =>
              addLog(`alpha ${sb.label}`, JSON.stringify(data))
            }
            onError={err =>
              addLog(`alpha ${sb.label}`, `ERROR: ${err.name} — ${err.message}`)
            }
          />
        ))}
        {alphas.length === 0 && (
          <Text style={styles.empty}>No alpha sandboxes yet.</Text>
        )}
      </ScrollView>

      {/* Beta sandboxes */}
      <Text style={[styles.groupLabel, {color: COLOR_BETA}]}>
        {'origin="beta"'} ({betas.length})
      </Text>
      <ScrollView
        horizontal
        style={styles.cardRow}
        contentContainerStyle={styles.cardRowContent}>
        {betas.map(sb => (
          <SandboxCard
            key={sb.key}
            entry={sb}
            color={COLOR_BETA}
            idleTTL={DEFAULT_TTL}
            onRemove={() => removeSandbox(sb.key)}
            onMessage={data => addLog(`beta ${sb.label}`, JSON.stringify(data))}
            onError={err =>
              addLog(`beta ${sb.label}`, `ERROR: ${err.name} — ${err.message}`)
            }
          />
        ))}
        {betas.length === 0 && (
          <Text style={styles.empty}>No beta sandboxes yet.</Text>
        )}
      </ScrollView>

      {/* Isolated sandboxes */}
      <Text style={[styles.groupLabel, {color: COLOR_ISOLATED}]}>
        no origin / isolated ({isolated.length})
      </Text>
      <ScrollView
        horizontal
        style={styles.cardRow}
        contentContainerStyle={styles.cardRowContent}>
        {isolated.map(sb => (
          <SandboxCard
            key={sb.key}
            entry={sb}
            color={COLOR_ISOLATED}
            idleTTL={DEFAULT_TTL}
            onRemove={() => removeSandbox(sb.key)}
            onMessage={data =>
              addLog(`isolated ${sb.label}`, JSON.stringify(data))
            }
            onError={err =>
              addLog(
                `isolated ${sb.label}`,
                `ERROR: ${err.name} — ${err.message}`
              )
            }
          />
        ))}
        {isolated.length === 0 && (
          <Text style={styles.empty}>No isolated sandboxes yet.</Text>
        )}
      </ScrollView>

      {/* Event log */}
      <Text style={styles.logTitle}>Event Log</Text>
      <ScrollView
        ref={logScrollRef}
        style={styles.logScroll}
        onContentSizeChange={() => logScrollRef.current?.scrollToEnd()}>
        {log.map((e, i) => (
          <Text key={i} style={styles.logLine}>
            <Text style={styles.logSource}>[{e.source}]</Text> {e.text}
          </Text>
        ))}
      </ScrollView>
    </SafeAreaView>
  )
}

type SandboxCardProps = {
  entry: SandboxEntry
  color: string
  idleTTL: number | (() => number)
  onRemove: () => void
  onMessage: (data: unknown) => void
  onError: (err: {name: string; message: string}) => void
}

function SandboxCard({
  entry,
  color,
  idleTTL,
  onRemove,
  onMessage,
  onError,
}: SandboxCardProps) {
  return (
    <View style={[styles.card, {borderColor: color}]}>
      <View style={[styles.cardHeader, {backgroundColor: color}]}>
        <Text style={styles.cardLabel}>
          {entry.origin || 'isolated'} {entry.label}
        </Text>
        <Text style={styles.cardRemove} onPress={onRemove}>
          ✕
        </Text>
      </View>
      <SandboxReactNativeView
        origin={entry.origin || undefined}
        allowedOrigins={[ORIGIN_ALPHA, ORIGIN_BETA]}
        idleTTL={idleTTL}
        componentName="SandboxApp"
        jsBundleSource="sandbox"
        onMessage={onMessage}
        onError={onError}
        style={styles.sandboxView}
      />
    </View>
  )
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    paddingTop: Platform.OS === 'android' ? StatusBar.currentHeight : 0,
  },
  heading: {
    fontSize: 20,
    fontWeight: '700',
    textAlign: 'center',
    marginTop: 8,
    marginBottom: 2,
  },
  subtitle: {
    fontSize: 11,
    color: '#6c757d',
    textAlign: 'center',
    marginBottom: 6,
    paddingHorizontal: 16,
  },
  controls: {
    flexDirection: 'row',
    justifyContent: 'space-evenly',
    paddingHorizontal: 8,
    paddingBottom: 4,
  },
  groupLabel: {
    fontSize: 12,
    fontWeight: '600',
    paddingHorizontal: 12,
    paddingTop: 2,
  },
  cardRow: {height: 150, flexGrow: 0},
  cardRowContent: {paddingHorizontal: 8, gap: 8},
  card: {
    width: 200,
    borderWidth: 2,
    borderRadius: 8,
    overflow: 'hidden',
  },
  cardLabel: {
    color: '#fff',
    fontSize: 11,
    fontWeight: '600',
    textAlign: 'center',
    paddingVertical: 2,
    flex: 1,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  cardRemove: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '700',
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  sandboxView: {flex: 1},
  empty: {
    color: '#999',
    fontStyle: 'italic',
    alignSelf: 'center',
    paddingTop: 60,
  },
  logTitle: {
    fontSize: 14,
    fontWeight: '600',
    paddingHorizontal: 12,
    paddingTop: 4,
  },
  logScroll: {flex: 1, paddingHorizontal: 12, paddingTop: 4},
  logLine: {fontSize: 11, fontFamily: 'monospace', marginBottom: 2},
  logSource: {fontWeight: '700', color: '#8232ff'},
})
