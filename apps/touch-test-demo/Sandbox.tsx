import React, {useState} from 'react'
import {
  LogBox,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'

// Padding views inserted before specific buttons to push their tags
// to desired values for collision testing.
// Each View consumes 1 tag in the React surface.
//
// Why these specific counts?
// React Native Fabric allocates view tags sequentially from a shared counter.
// The sandbox surface starts at a known offset relative to the host surface.
// By inserting invisible zero-height Views before a button, we consume tag IDs
// and push the button's tag to a value that collides with a host view tag.
//
// Current targets (Android, RN 0.76.x):
//   Button 2 → tag 34  (matches host "Host Button" in Test 1)
//   Button 3 → tag 92  (matches host overlay button in Test 2)
//
// FRAGILITY NOTE: These counts are sensitive to:
//   - The number of host views rendered before the sandbox surface starts
//   - React Native's internal tag allocation strategy (may change across RN versions)
//   - The number of views rendered inside the sandbox before these buttons
// If tags drift after an RN upgrade or component tree change, adjust the counts
// here and verify with the on-screen "(tag: N)" labels in the demo UI.
const PADDING_BEFORE_BUTTON: Record<number, number> = {
  2: 5, // push button 2 → tag 34
  3: 24, // push button 3 → tag 92
}

function TagPadding({count}: {count: number}) {
  return (
    <>
      {Array.from({length: count}, (_, i) => (
        <View key={`pad-${i}`} style={styles.pad} />
      ))}
    </>
  )
}

export default function Sandbox() {
  const [status, setStatus] = useState('Ready')
  const [tags, setTags] = useState<Record<number, number>>({})

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.status}>Sandbox status: {status}</Text>
      {[1, 2, 3, 4, 5].map(n => (
        <React.Fragment key={n}>
          {PADDING_BEFORE_BUTTON[n] && (
            <TagPadding count={PADDING_BEFORE_BUTTON[n]} />
          )}
          <TouchableOpacity
            style={styles.button}
            onLayout={e => {
              const tag = (e as any).nativeEvent?.target
              if (tag != null) setTags(prev => ({...prev, [n]: tag}))
            }}
            onPress={() => setStatus(`Button ${n} pressed`)}>
            <Text style={styles.buttonText}>
              Button {n}
              {tags[n] != null ? ` (tag: ${tags[n]})` : ''}
            </Text>
          </TouchableOpacity>
          {n < 5 && <View style={styles.spacer} />}
        </React.Fragment>
      ))}
    </ScrollView>
  )
}

LogBox.ignoreAllLogs()

const styles = StyleSheet.create({
  container: {
    padding: 16,
    justifyContent: 'center',
  },
  spacer: {
    height: 16,
  },
  pad: {
    height: 0,
  },
  status: {
    fontSize: 14,
    fontStyle: 'italic',
    marginBottom: 16,
    color: '#666',
  },
  button: {
    backgroundColor: '#2196F3',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonText: {
    color: '#ffffff',
    fontWeight: '600',
    fontSize: 15,
  },
})
