import {resolveJsBundleSource} from '../resolveBundleSource'

describe('resolveJsBundleSource', () => {
  it('passes through an already-absolute URL untouched', () => {
    expect(
      resolveJsBundleSource(
        'https://cdn.example.com/sandbox.bundle',
        'http://localhost:8081/index.bundle?platform=ios&dev=true',
        true
      )
    ).toBe('https://cdn.example.com/sandbox.bundle')
  })

  it('passes through the bare name in release builds', () => {
    expect(resolveJsBundleSource('sandbox', undefined, false)).toBe('sandbox')
  })

  it('passes through the bare name when the host script URL is unavailable', () => {
    expect(resolveJsBundleSource('sandbox', undefined, true)).toBe('sandbox')
  })

  it('derives a sibling bundle URL from the host script URL in dev', () => {
    expect(
      resolveJsBundleSource(
        'sandbox',
        'http://localhost:8081/apps/demo/index.bundle?platform=ios&dev=true&hot=false&minify=false',
        true
      )
    ).toBe(
      'http://localhost:8081/apps/demo/sandbox.bundle?platform=ios&dev=true&hot=false&minify=false'
    )
  })

  it('strips launcher-specific params (e.g. Expo Router transform params)', () => {
    expect(
      resolveJsBundleSource(
        'sandbox',
        'http://192.168.1.10:8081/index.bundle?platform=ios&dev=true&transform.routerRoot=app&transform.bytecode=1',
        true
      )
    ).toBe('http://192.168.1.10:8081/sandbox.bundle?platform=ios&dev=true')
  })

  it('normalizes a bundle name that already carries an extension', () => {
    expect(
      resolveJsBundleSource(
        'sandbox.bundle',
        'http://localhost:8081/index.bundle?platform=android&dev=true',
        true
      )
    ).toBe('http://localhost:8081/sandbox.bundle?platform=android&dev=true')
  })
})
