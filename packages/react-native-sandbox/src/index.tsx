import type React from 'react'
import {
  forwardRef,
  useCallback,
  useImperativeHandle,
  useMemo,
  useRef,
} from 'react'
import type {NativeSyntheticEvent} from 'react-native'
import {StyleProp, StyleSheet, View, ViewProps, ViewStyle} from 'react-native'

import type {NativeSandboxReactNativeViewComponentType} from '../specs/NativeSandboxReactNativeView'
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

/**
 * Generic object type for props that can contain any key-value pairs.
 * Used for initialProperties and launchOptions to allow flexible configuration.
 */
type GenericProps = {
  [key: string]: any
}

let sandboxCounter = 0
const generateSandboxId = (): string => {
  return `sandbox:${++sandboxCounter}`
}

export interface SandboxReactNativeViewProps extends ViewProps {
  /** Optional unique identifier for the sandbox instance */
  // TODO rename to not colide with ViewProps.id
  id?: string

  /**
   * The name of the React Native component to load in the sandbox.
   * This should match the component name registered in your JavaScript bundle.
   */
  componentName: string

  /**
   * @deprecated Use componentName instead. Will be removed in a future version.
   * The name of the React Native component to load in the sandbox.
   * This should match the component name registered in your JavaScript bundle.
   */
  moduleName?: string

  /**
   * Optional path or URL to the JavaScript bundle to load.
   * If not provided, the default bundle will be used.
   */
  jsBundleSource?: string

  /**
   * Initial properties to pass to the sandboxed React Native app.
   * These will be available as props in the root component of the sandbox.
   */
  initialProperties?: GenericProps

  /**
   * Launch options for configuring the sandbox environment.
   * Platform-specific options for initializing the React Native instance.
   */
  launchOptions?: GenericProps

  /**
   * Array of additional TurboModule names to allow in the sandbox.
   * These will be merged with the default whitelist for enhanced functionality.
   */
  allowedTurboModules?: string[]

  /**
   * Callback function called when the sandbox sends a message to the parent.
   * Use this for bidirectional communication between parent and sandbox.
   *
   * @param data - The data sent from the sandbox, can be any serializable value
   */
  onMessage?: (data: unknown) => void

  /**
   * Callback function called when an error occurs in the sandbox.
   *
   * @param error - Error details including name, message, stack trace, and fatality
   */
  onError?: (error: ErrorEvent) => void
}

/**
 * Ref interface for SandboxReactNativeView component.
 * Provides methods to interact with the sandbox from the parent component.
 *
 * @example
 * ```tsx
 * const sandboxRef = useRef<SandboxReactNativeViewRef>(null);
 *
 * // Send a message to the sandbox
 * sandboxRef.current?.postMessage({
 *   type: 'update',
 *   payload: { theme: 'light' }
 * });
 * ```
 */
export interface SandboxReactNativeViewRef {
  /**
   * Send a message to the sandboxed React Native instance.
   * The message will be serialized to JSON before transmission.
   *
   * @param message - Any serializable data to send to the sandbox
   */
  postMessage: (message: unknown) => void
}

/**
 * SandboxReactNativeView component for running isolated React Native instances.
 *
 * This component creates a secure sandbox environment where you can run multiple
 * React Native apps side-by-side with controlled access to TurboModules and
 * bidirectional communication capabilities.
 *
 * Key features:
 * - Security isolation through TurboModule whitelisting
 * - Bidirectional communication via postMessage
 * - Error handling and monitoring
 * - Support for custom launch configurations
 *
 * @example
 * Basic usage:
 * ```tsx
 * function App() {
 *   const sandboxRef = useRef<SandboxReactNativeViewRef>(null);
 *
 *   const handleMessage = (data: unknown) => {
 *     console.log('Message from sandbox:', data);
 *   };
 *
 *   const sendMessage = () => {
 *     sandboxRef.current?.postMessage({ action: 'refresh' });
 *   };
 *
 *   return (
 *     <SandboxReactNativeView
 *       ref={sandboxRef}
 *       componentName="MyDynamicApp"
 *       jsBundleSource="https://example.com/app.bundle.js"
 *       initialProperties={{ userId: '123', theme: 'dark' }}
 *       onMessage={handleMessage}
 *       onError={(error) => console.error('Sandbox error:', error)}
 *       style={{ flex: 1 }}
 *     />
 *   );
 * }
 * ```
 *
 * @example
 * Advanced usage with custom TurboModules:
 * ```tsx
 * <SandboxReactNativeView
 *   componentName="SecureApp"
 *   allowedTurboModules={['MyCustomModule', 'CryptoModule']}
 *   launchOptions={{ debugMode: false, securityLevel: 'high' }}
 *   onMessage={(data) => {
 *     // Handle different message types
 *     if (data?.type === 'auth') {
 *       handleAuthentication(data.payload);
 *     }
 *   }}
 * />
 * ```
 */
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
      componentName,
      moduleName,
      onMessage,
      onError,
      ...rest
    },
    ref
  ) => {
    const nativeRef =
      useRef<React.ComponentRef<NativeSandboxReactNativeViewComponentType> | null>(
        null
      )

    const sandboxId = useMemo(() => id || generateSandboxId(), [id])

    const postMessage = useCallback((message: any) => {
      if (nativeRef.current) {
        Commands.postMessage(nativeRef.current, JSON.stringify(message))
      }
    }, [])

    const _onError = useCallback(
      (e: NativeSyntheticEvent<ErrorEvent>) => {
        // @ts-ignore
        onError?.(e.nativeEvent as ErrorEvent)
      },
      [onError]
    )

    const _onMessage = useCallback(
      (e: NativeSyntheticEvent<MessageEvent>) => {
        // @ts-ignore
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

    // Handle backward compatibility for moduleName -> componentName
    const resolvedComponentName = useMemo(() => {
      if (componentName && moduleName) {
        console.warn(
          'Both componentName and moduleName are provided. Using componentName and ignoring moduleName. ' +
            'Please migrate to using componentName only as moduleName is deprecated.'
        )
        return componentName
      }

      if (moduleName) {
        console.warn(
          'moduleName is deprecated. Please use componentName instead. moduleName will be removed in a future version.'
        )
        return moduleName
      }

      if (!componentName) {
        throw new Error('Either componentName or moduleName must be provided')
      }

      return componentName
    }, [componentName, moduleName])

    const _jsBundleSource = useMemo(() => {
      if (jsBundleSource) {
        return jsBundleSource
      }
      return 'index'
    }, [jsBundleSource])

    return (
      <View style={style}>
        <NativeSandboxReactNativeView
          // @ts-ignore
          ref={nativeRef}
          id={sandboxId}
          componentName={resolvedComponentName}
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
