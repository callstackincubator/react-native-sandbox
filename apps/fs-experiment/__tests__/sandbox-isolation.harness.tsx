import {screen, userEvent} from '@react-native-harness/ui'
import React from 'react'
import {Platform} from 'react-native'
import {
  afterAll,
  beforeAll,
  describe,
  expect,
  it,
  render,
} from 'react-native-harness'

import App from '../App'

const isIOS = Platform.OS === 'ios'
const TEST_TIMEOUT = 60_000
const RENDER_TIMEOUT = 10_000
const SANDBOX_READY_TIMEOUT = 90_000

async function sleep(ms: number) {
  return new Promise(r => setTimeout(r, ms))
}

async function setSubstitution(enabled: boolean) {
  const wantLabel = enabled ? 'substitution-on' : 'substitution-off'
  if (screen.queryByAccessibilityLabel(wantLabel)) return

  await userEvent.press(await screen.findByTestId('substitution-switch'))
  await screen.findByAccessibilityLabel(wantLabel)
  await sleep(3000)
}

async function writeAndRead(
  mod: string,
  writer: 'host' | 'sandbox',
  reader: 'host' | 'sandbox',
  substitution: boolean,
  expectVisible: boolean
) {
  const content = `${writer}_${mod}_${substitution ? 'on' : 'off'}`

  await setSubstitution(substitution)

  await userEvent.press(await screen.findByTestId(`${writer}-seg-${mod}`))
  await userEvent.press(await screen.findByTestId(`${writer}-clear-btn`))
  await userEvent.type(
    await screen.findByTestId(`${writer}-content-input`),
    content
  )
  await userEvent.press(await screen.findByTestId(`${writer}-write-btn`))
  await screen.findByAccessibilityLabel(`Wrote: "${content}"`)

  await userEvent.press(await screen.findByTestId(`${reader}-seg-${mod}`))
  await userEvent.press(await screen.findByTestId(`${reader}-read-btn`))

  if (expectVisible) {
    await sleep(1000)
    await screen.findByAccessibilityLabel(`Read: "${content}"`)
  } else {
    await sleep(2000)
    const leaked = screen.queryByAccessibilityLabel(`Read: "${content}"`)
    expect(leaked).toBeNull()
  }
}

// ---------------------------------------------------------------------------
//  The harness tears down the rendered tree after every it() via an afterEach
//  that calls store.getState().setRenderedElement(null). We intercept that at
//  the store level so a single render(<App />) persists across all it() blocks.
// ---------------------------------------------------------------------------
const {store} = require('@react-native-harness/runtime/dist/ui/state.js')
const origSet = store.getState().setRenderedElement
let blockCleanup = false
store.getState().setRenderedElement = (el: unknown) => {
  if (el === null && blockCleanup) return
  origSet(el)
}

// ---------------------------------------------------------------------------
//  * rnfs — iOS only (react-native-fs incompatible with Android New Arch)
//  * file-access OFF on Android — isolated due to SandboxContextWrapper
//  * async-storage is not tested: because in memore data read only once at start
// ---------------------------------------------------------------------------

describe('Substitution OFF', () => {
  beforeAll(async () => {
    blockCleanup = true
    await render(<App />, {timeout: RENDER_TIMEOUT})
    await screen.findByTestId(
      'sandbox-ready',
      {},
      {timeout: SANDBOX_READY_TIMEOUT}
    )
  }, SANDBOX_READY_TIMEOUT + RENDER_TIMEOUT)

  if (isIOS) {
    it(
      'rnfs | sandbox -> host | shared',
      () => writeAndRead('rnfs', 'sandbox', 'host', false, true),
      TEST_TIMEOUT
    )

    it(
      'rnfs | host -> sandbox | shared',
      () => writeAndRead('rnfs', 'host', 'sandbox', false, true),
      TEST_TIMEOUT
    )
  }

  it(
    'file-access | sandbox -> host | shared',
    () => writeAndRead('file-access', 'sandbox', 'host', false, isIOS),
    TEST_TIMEOUT
  )

  it(
    'file-access | host -> sandbox | shared',
    () => writeAndRead('file-access', 'host', 'sandbox', false, isIOS),
    TEST_TIMEOUT
  )
})

describe('Substitution ON', () => {
  if (isIOS) {
    it(
      'rnfs | sandbox -> host | isolated',
      () => writeAndRead('rnfs', 'sandbox', 'host', true, false),
      TEST_TIMEOUT
    )

    it(
      'rnfs | host -> sandbox | isolated',
      () => writeAndRead('rnfs', 'host', 'sandbox', true, false),
      TEST_TIMEOUT
    )
  }

  // Android: toggling substitution remounts the SandboxReactNativeView but the
  // old root's native nodes linger in the view hierarchy. The harness's
  // queryByTestId returns stale nodes, making sandbox interaction unreliable.
  if (isIOS) {
    it(
      'file-access | sandbox -> host | isolated',
      () => writeAndRead('file-access', 'sandbox', 'host', true, false),
      TEST_TIMEOUT
    )
  }

  it(
    'file-access | host -> sandbox | isolated',
    () => writeAndRead('file-access', 'host', 'sandbox', true, false),
    TEST_TIMEOUT
  )

  afterAll(() => {
    blockCleanup = false
    store.getState().setRenderedElement = origSet
    origSet(null)
  })
})
