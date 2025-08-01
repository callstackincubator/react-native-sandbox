import type React from 'react'
import type {HostComponent, ViewProps} from 'react-native'
import {
  codegenNativeCommands,
  codegenNativeComponent,
  CodegenTypes,
} from 'react-native'

export interface ErrorEvent {
  name: string
  message: string
  stack?: string
  isFatal?: boolean
}

export interface MessageEvent {
  data: CodegenTypes.UnsafeMixed
}

export interface NativeProps extends ViewProps {
  // Component properties
  moduleName: string
  jsBundleSource?: string
  initialProperties?: CodegenTypes.UnsafeMixed
  launchOptions?: CodegenTypes.UnsafeMixed
  allowedTurboModules?: readonly string[]

  // Event handler presence flags
  hasOnMessageHandler?: boolean
  hasOnErrorHandler?: boolean

  // Event handlers
  onMessage?: CodegenTypes.BubblingEventHandler<MessageEvent>
  onError?: CodegenTypes.BubblingEventHandler<ErrorEvent>
}

export type NativeSandboxReactNativeViewComponentType =
  HostComponent<NativeProps>

interface NativeCommands {
  postMessage: (
    viewRef: React.ElementRef<NativeSandboxReactNativeViewComponentType>,
    message: string
  ) => void
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['postMessage'],
})

export default codegenNativeComponent<NativeProps>(
  'SandboxReactNativeView'
) as NativeSandboxReactNativeViewComponentType
