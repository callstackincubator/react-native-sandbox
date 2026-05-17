/**
 * Touch Test Demo
 *
 * Single scrollable page combining Touch Bleed and Overlay tests.
 * Minimal host views to keep tag values low and predictable.
 */
import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React, {useState} from 'react'
import {
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'

// ─── Padding helper ─────────────────────────────────────────────────────────

function TagPadding({count}: {count: number}) {
  return (
    <>
      {Array.from({length: count}, (_, i) => (
        <View key={i} style={styles.pad} />
      ))}
    </>
  )
}

// ─── App ────────────────────────────────────────────────────────────────────

export default function App() {
  const [pressCount, setPressCount] = useState(0)
  const [hostTag, setHostTag] = useState<number | null>(null)
  const [overlayVisible, setOverlayVisible] = useState(false)
  const [overlayPressCount, setOverlayPressCount] = useState(0)
  const [overlayBtnTag, setOverlayBtnTag] = useState<number | null>(null)

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView>
        {/* ── Test 1: Touch Bleed ── */}
        <View style={styles.section}>
          <Text style={styles.title}>Test 1: Touch Bleed</Text>
          <Text style={styles.description}>
            Press a sandbox button whose tag matches the host button tag. Watch
            if the host button highlights or press count increases.
          </Text>

          <TagPadding count={10} />

          <TouchableOpacity
            style={styles.hostButton}
            onLayout={e => {
              const tag = (e as any).nativeEvent?.target
              if (tag != null) setHostTag(tag)
            }}
            onPress={() => setPressCount(c => c + 1)}>
            <Text style={styles.buttonText}>
              Host Button{hostTag != null ? ` (tag: ${hostTag})` : ''}
            </Text>
          </TouchableOpacity>
          <Text style={styles.result}>
            Press count: {pressCount}{' '}
            {pressCount > 0 ? '❌ BLEED DETECTED' : '✅ No bleed'}
          </Text>
        </View>

        <View style={styles.sandboxSection}>
          <Text style={styles.sectionHeader}>Sandbox (Touch Bleed)</Text>
          <SandboxReactNativeView
            style={styles.sandbox}
            componentName={'SandboxedDemo'}
            jsBundleSource={'sandbox.android.bundle'}
            onError={error => console.warn('Sandbox error:', error)}
          />
        </View>

        <View style={styles.divider} />

        {/* ── Test 2: Overlay over Sandbox ── */}
        <View style={styles.section}>
          <Text style={styles.title}>Test 2: Overlay over Sandbox</Text>
          <Text style={styles.description}>
            Tests that host views rendered on top of a sandbox correctly receive
            touches without bleeding into sandbox buttons.{'\n\n'}
            Expected behavior:{'\n'}• Overlay buttons — should fire (count
            increments){'\n'}• Card area over sandbox — should NOT fire sandbox
            buttons{'\n'}• Grey backdrop — should block sandbox touches{'\n'}•
            Top-half sandbox buttons (no overlay) — should work normally
          </Text>

          <TouchableOpacity
            style={styles.actionButton}
            onLayout={e => {
              const tag = (e as any).nativeEvent?.target
              if (tag != null) setOverlayBtnTag(tag)
            }}
            onPress={() => setOverlayVisible(v => !v)}>
            <Text style={styles.buttonText}>
              {overlayVisible ? 'Hide Overlay' : 'Show Overlay'}
              {overlayBtnTag != null ? ` (tag: ${overlayBtnTag})` : ''}
            </Text>
          </TouchableOpacity>

          <Text style={styles.result}>
            Overlay presses: {overlayPressCount}
            {overlayPressCount > 0 ? ' ✅' : ''}
          </Text>
        </View>

        <View style={styles.sandboxSection}>
          <Text style={styles.sectionHeader}>Sandbox (Overlay)</Text>
          <View style={{position: 'relative'}}>
            <SandboxReactNativeView
              style={styles.sandbox}
              componentName={'SandboxedDemo'}
              jsBundleSource={'sandbox.android.bundle'}
              onError={error => console.warn('Sandbox error:', error)}
            />
            {overlayVisible && (
              <View style={overlayStyles.backdrop}>
                <View style={overlayStyles.card}>
                  <Text style={overlayStyles.cardTitle}>Host Overlay</Text>
                  <Text style={overlayStyles.cardDesc}>
                    This view is rendered by the host ON TOP of the sandbox.
                    Tapping the button below should work normally.
                  </Text>
                  <TouchableOpacity
                    style={overlayStyles.overlayButton}
                    onPress={() => setOverlayPressCount(c => c + 1)}>
                    <Text style={styles.buttonText}>
                      Tap Me (overlay) — count: {overlayPressCount}
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[
                      overlayStyles.overlayButton,
                      {backgroundColor: '#ff3b30', marginTop: 8},
                    ]}
                    onPress={() => setOverlayVisible(false)}>
                    <Text style={styles.buttonText}>Dismiss</Text>
                  </TouchableOpacity>
                </View>
              </View>
            )}
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  )
}

// ─── Styles ─────────────────────────────────────────────────────────────────

const overlayStyles = StyleSheet.create({
  backdrop: {
    position: 'absolute',
    top: '50%',
    left: '15%',
    right: '15%',
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.3)',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 10,
    elevation: 0,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#000000ff',
    padding: 24,
    width: '65%',
    marginTop: -150,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 4},
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 12,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 8,
  },
  cardDesc: {
    fontSize: 14,
    color: '#666',
    marginBottom: 16,
    lineHeight: 20,
  },
  overlayButton: {
    backgroundColor: '#34c759',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
  },
})

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  section: {
    padding: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    marginBottom: 8,
  },
  sectionHeader: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 8,
  },
  description: {
    fontSize: 14,
    color: '#666',
    marginBottom: 16,
    lineHeight: 20,
  },
  pad: {
    height: 1,
  },
  hostButton: {
    backgroundColor: '#007aff',
    paddingVertical: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 8,
  },
  actionButton: {
    backgroundColor: '#5856d6',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 12,
    marginBottom: 8,
  },
  buttonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
  result: {
    fontSize: 15,
    marginVertical: 4,
  },
  sandboxSection: {
    padding: 16,
    borderTopWidth: 1,
    borderTopColor: '#ccc',
  },
  sandbox: {
    height: 400,
    borderWidth: 1,
    borderColor: '#8232ff',
    borderRadius: 4,
  },
  divider: {
    height: 8,
    backgroundColor: '#f0f0f0',
    marginVertical: 8,
  },
})
