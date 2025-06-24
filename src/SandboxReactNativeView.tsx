import { ElementRef, forwardRef, useCallback, useEffect, useId, useImperativeHandle, useMemo, useRef } from "react";
import { findNodeHandle, HostComponent, NativeSyntheticEvent, requireNativeComponent, StyleProp, StyleSheet, UIManager, View, ViewProps, ViewStyle } from "react-native";
import type {
  DirectEventHandler,
} from 'react-native/Libraries/Types/CodegenTypes';

import MultiReactMediatorModule from '../specs/NativeMultiReactMediator'


type GenericProps = {
  [key: string]: any;
};

export interface NativeSandboxReactNativeViewProps extends ViewProps {
  contextId: string;
  moduleName: string;
  jsBundleName?: string;
  initialProperties?: GenericProps;
  launchOptions?: GenericProps;
  onError?: DirectEventHandler<{}>;
}

export interface SandboxReactNativeViewProps extends ViewProps {
  moduleName: string;
  jsBundleName?: string;
  initialProperties?: GenericProps;
  launchOptions?: GenericProps;
  onMessage?: (payload: unknown) => void;
  onError?: DirectEventHandler<{}>;
}

export interface SandboxReactNativeViewRef {
  postMessage: (message: object) => void;
}

type NativeComponentType = HostComponent<NativeSandboxReactNativeViewProps>;

const NativeComponent = requireNativeComponent<NativeSandboxReactNativeViewProps>('SandboxReactNativeView') as NativeComponentType;

const SandboxReactNativeView = forwardRef<SandboxReactNativeViewRef, SandboxReactNativeViewProps>(
  (
    {
      onMessage,
      onError,
      style,
      ...rest
    },
    ref,
  ) => {
    const nativeRef = useRef<ElementRef<typeof NativeComponent>>(null);
    const contextId = useId();

    const postMessage = useCallback((message: any) => {
      MultiReactMediatorModule.postMessage(`host_${contextId}`, message);
    }, []);

    const _onError = useCallback(
      (e: NativeSyntheticEvent<{}>) => {
        onError?.(e);
      },
      [onError],
    );

    useImperativeHandle(
      ref,
      () => ({
        postMessage,
      }),
      [
        postMessage,
      ],
    );

    const _renderOverlay = useCallback(() => {
      // TODO implement some loading/error/handling screen
      return null;
    }, []);

    const _style: StyleProp<ViewStyle> = useMemo(
      () => ({
        ...StyleSheet.absoluteFillObject,
      }),
      [],
    );

    useEffect(() => {
      if (onMessage) {
        MultiReactMediatorModule.registerRuntime(`${contextId}_host`, onMessage);
      }
    }, []);

    return (
      <View style={style}>
        <NativeComponent
          ref={nativeRef}
          onError={_onError}
          style={_style}
          contextId={contextId}
          {...rest} />
        {_renderOverlay()}
      </View>
    );
  },
);

SandboxReactNativeView.displayName = 'SandboxReactNativeView';
export default SandboxReactNativeView;