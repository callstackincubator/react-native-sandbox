import {
  forwardRef,
  useCallback,
  useImperativeHandle,
  useMemo,
  useRef,
} from 'react'
import {
  NativeSyntheticEvent,
  StyleProp,
  StyleSheet,
  View,
  ViewProps,
  ViewStyle,
} from 'react-native'

import NativeSandboxReactNativeView, {
  Commands,
  ErrorEvent,
} from '../specs/NativeSandboxReactNativeView'

const SANDBOX_TURBOMODULES_WHITELIST = [
  'NativeMicrotasksCxx',
  'NativePerformanceCxx',
  'RedBox',
  'DevMenu',
  'DevLoadingView',
  'EventDispatcher',
  'ImageLoader',
  'ExceptionsManager',
  'PlatformConstants',
  'DevSettings',
  'SettingsManager',
  'AppState',
  'SourceCode',
  'WebSocketModule',
  'Networking',
  'DeviceInfo',
  'AccessibilityManager',
  'LinkingManager',
  'BlobModule',
  'LogBox',
  'Appearance',
  'ReactDevToolsRuntimeSettingsModule',
  'NativeReactNativeFeatureFlagsCxx',
  'NativeAnimatedTurboModule',
  'KeyboardObserver',
  'I18nManager',
]

type GenericProps = {
  [key: string]: any
}

export interface SandboxReactNativeViewProps extends ViewProps {
  moduleName: string
  jsBundleSource?: string
  initialProperties?: GenericProps
  launchOptions?: GenericProps
  allowedTurboModules?: string[]
  onMessage?: (data: unknown) => void
  onError?: (error: ErrorEvent) => void
}

export interface SandboxReactNativeViewRef {
  postMessage: (message: unknown) => void
}

const SandboxReactNativeView = forwardRef<
  SandboxReactNativeViewRef,
  SandboxReactNativeViewProps
>(({onMessage, onError, allowedTurboModules, style, ...rest}, ref) => {
  const nativeRef =
    useRef<React.ComponentRef<typeof NativeSandboxReactNativeView>>(null)

  const postMessage = useCallback((message: any) => {
    if (nativeRef.current) {
      Commands.postMessage(nativeRef.current, JSON.stringify(message))
    }
  }, [])

  const _onError = useCallback(
    (e: NativeSyntheticEvent<ErrorEvent>) => {
      onError?.(e.nativeEvent)
    },
    [onError]
  )

  const _onMessage = useCallback(
    (e: NativeSyntheticEvent<{data: any}>) => {
      onMessage?.(e.nativeEvent.data)
    },
    [onMessage]
  )

  useImperativeHandle(
    ref,
    () => ({
      postMessage,
    }),
    [postMessage]
  )

  const _renderOverlay = useCallback(() => {
    // TODO implement some loading/error/handling screen
    return null
  }, [])

  const _style: StyleProp<ViewStyle> = useMemo(
    () => ({
      ...StyleSheet.absoluteFillObject,
    }),
    []
  )

  const _allowedTurboModules = [
    ...new Set([
      ...(allowedTurboModules ?? []),
      ...SANDBOX_TURBOMODULES_WHITELIST,
    ]),
  ]

  return (
    <View style={style}>
      <NativeSandboxReactNativeView
        ref={nativeRef}
        hasOnMessageHandler={!!onMessage}
        hasOnErrorHandler={!!onError}
        onError={onError ? _onError : undefined}
        onMessage={onMessage ? _onMessage : undefined}
        allowedTurboModules={_allowedTurboModules}
        style={_style}
        {...rest}
      />
      {_renderOverlay()}
    </View>
  )
})

SandboxReactNativeView.displayName = 'SandboxReactNativeView'
export default SandboxReactNativeView
