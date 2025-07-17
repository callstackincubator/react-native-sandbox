import {
  ElementRef,
  forwardRef,
  useCallback,
  useImperativeHandle,
  useMemo,
  useRef,
} from 'react'
import {
  findNodeHandle,
  HostComponent,
  NativeSyntheticEvent,
  requireNativeComponent,
  StyleProp,
  StyleSheet,
  UIManager,
  View,
  ViewProps,
  ViewStyle,
} from 'react-native'
import type {DirectEventHandler} from 'react-native/Libraries/Types/CodegenTypes'

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
]

type GenericProps = {
  [key: string]: any
}

interface IsFatalError extends Error {
  isFatal?: boolean
}

export interface NativeSandboxReactNativeViewProps extends ViewProps {
  moduleName: string
  jsBundleSource?: string
  initialProperties?: GenericProps
  launchOptions?: GenericProps
  allowedTurboModules?: string[]
  onError?: DirectEventHandler<IsFatalError>
  onMessage?: DirectEventHandler<unknown>
}

export interface SandboxReactNativeViewProps extends ViewProps {
  moduleName: string
  jsBundleSource?: string
  initialProperties?: GenericProps
  launchOptions?: GenericProps
  allowedTurboModules?: string[]
  onMessage?: (payload: unknown) => void
  onError?: (error: IsFatalError) => void
}

export interface SandboxReactNativeViewRef {
  postMessage: (message: object) => void
}

type NativeComponentType = HostComponent<NativeSandboxReactNativeViewProps>

const NativeComponent =
  requireNativeComponent<NativeSandboxReactNativeViewProps>(
    'SandboxReactNativeView'
  ) as NativeComponentType

const SandboxReactNativeView = forwardRef<
  SandboxReactNativeViewRef,
  SandboxReactNativeViewProps
>(({onMessage, onError, allowedTurboModules, style, ...rest}, ref) => {
  const nativeRef = useRef<ElementRef<typeof NativeComponent>>(null)

  const postMessage = useCallback((message: any) => {
    const reactTag = findNodeHandle(nativeRef.current)
    UIManager.dispatchViewManagerCommand(
      reactTag,
      UIManager.getViewManagerConfig('SandboxReactNativeView').Commands
        .postMessage,
      [message]
    )
  }, [])

  const _onError = useCallback(
    (e: NativeSyntheticEvent<IsFatalError>) => {
      onError?.(e.nativeEvent as Error)
    },
    [onError]
  )

  const _onMessage = useCallback(
    (e: NativeSyntheticEvent<unknown>) => {
      onMessage?.(e.nativeEvent)
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
      <NativeComponent
        ref={nativeRef}
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
