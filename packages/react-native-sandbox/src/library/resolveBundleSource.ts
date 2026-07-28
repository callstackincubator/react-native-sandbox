// Query params that only affect how a bundle is transformed/served by Metro
// (platform, dev/hot/minify flags, etc). Anything else, like Expo Router's
// `transform.routerRoot`, describes the host bundle's own setup and breaks
// Metro when forwarded to an unrelated sibling bundle, so it gets dropped.
const FORWARDABLE_QUERY_PARAMS = [
  'platform',
  'dev',
  'hot',
  'minify',
  'runModule',
  'excludeSource',
  'inlineSourceMap',
  'lazy',
]

const ABSOLUTE_URL_PATTERN = /^[a-z][a-z0-9+.-]*:\/\//i

/**
 * Resolves the final `jsBundleSource` to hand to native.
 *
 * In dev, Metro serves the host bundle from a URL that native's own launcher
 * (RN CLI, or a wrapper like Expo's dev-client) resolved. `hostScriptURL` is
 * that same URL, read back from the already-running host JS (see the
 * SourceCode native module). Because it reflects wherever the host bundle
 * actually loaded from, deriving the sandbox's bundle URL from it works the
 * same way no matter which launcher stood up the host, with no native-side
 * knowledge of Expo (or any other launcher) required.
 */
export function resolveJsBundleSource(
  jsBundleSource: string,
  hostScriptURL: string | null | undefined,
  isDev: boolean
): string {
  if (ABSOLUTE_URL_PATTERN.test(jsBundleSource)) {
    return jsBundleSource
  }

  if (!isDev || !hostScriptURL) {
    return jsBundleSource
  }

  const [base, query = ''] = hostScriptURL.split('?')
  const lastSlash = base.lastIndexOf('/')
  if (lastSlash === -1) {
    return jsBundleSource
  }

  const dir = base.substring(0, lastSlash)
  const bundleName = jsBundleSource.replace(/\.(bundle|jsbundle)$/, '')

  const forwardedQuery = query
    .split('&')
    .filter(pair => FORWARDABLE_QUERY_PARAMS.includes(pair.split('=')[0]))
    .join('&')

  return `${dir}/${bundleName}.bundle${forwardedQuery ? `?${forwardedQuery}` : ''}`
}
