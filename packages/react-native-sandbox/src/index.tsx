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
  'FrameRateLogger',
]

type GenericProps = {
  [key: string]: any
}

let sandboxCounter = 0
const generateSandboxId = (): string => {
  return `sandbox:${++sandboxCounter}`
}

export interface SandboxReactNativeViewProps extends ViewProps {
  id?: string
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
>(
  (
    {
      id,
      jsBundleSource,
      allowedTurboModules,
      style,
      onMessage,
      onError,
      ...rest
    },
    ref
  ) => {
    const nativeRef =
      useRef<React.ComponentRef<typeof NativeSandboxReactNativeView>>(null)

    const sandboxId = useMemo(() => id || generateSandboxId(), [id])

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

    const _allowedTurboModules = useMemo(
      () => [
        ...new Set([
          ...(allowedTurboModules ?? []),
          ...SANDBOX_TURBOMODULES_WHITELIST,
        ]),
      ],
      [allowedTurboModules]
    )

    const _jsBundleSource = useMemo(() => {
      if (jsBundleSource) {
        return jsBundleSource
      }
      return 'index'
    }, [jsBundleSource])

    return (
      <View style={style}>
        <NativeSandboxReactNativeView
          ref={nativeRef}
          id={sandboxId}
          jsBundleSource={_jsBundleSource}
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
  }
)

SandboxReactNativeView.displayName = 'SandboxReactNativeView'
export default SandboxReactNativeView
