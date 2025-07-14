import { ElementRef, forwardRef, useCallback, useId, useImperativeHandle, useMemo, useRef } from "react";
import { findNodeHandle, HostComponent, NativeSyntheticEvent, requireNativeComponent, StyleProp, StyleSheet, UIManager, View, ViewProps, ViewStyle } from "react-native";
import type {
  DirectEventHandler,
} from 'react-native/Libraries/Types/CodegenTypes';

const SANDBOX_TURBOMODULES_WHITELIST = ['NativeMicrotasksCxx'];

type GenericProps = {
  [key: string]: any;
};

interface IsFatalError extends Error {
  isFatal?: boolean;
}

export interface NativeSandboxReactNativeViewProps extends ViewProps {
  moduleName: string;
  jsBundleName?: string;
  initialProperties?: GenericProps;
  launchOptions?: GenericProps;
  allowedTurboModules?: string[];
  onError?: DirectEventHandler<{}>;
  onMessage?: DirectEventHandler<{}>;
}

export interface SandboxReactNativeViewProps extends ViewProps {
  moduleName: string;
  jsBundleName?: string;
  initialProperties?: GenericProps;
  launchOptions?: GenericProps;
  allowedTurboModules?: string[];
  onMessage?: (payload: unknown) => void;
  onError?: (error: IsFatalError) => void;
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
      allowedTurboModules,
      style,
      ...rest
    },
    ref,
  ) => {
    const nativeRef = useRef<ElementRef<typeof NativeComponent>>(null);

    const postMessage = useCallback((message: any) => {
      const reactTag = findNodeHandle(nativeRef.current);
      UIManager.dispatchViewManagerCommand(
        reactTag,
        UIManager.getViewManagerConfig('SandboxReactNativeView').Commands.postMessage,
        [message]
      );
    }, []);

    const _onError = onError ? useCallback(
      (e: NativeSyntheticEvent<{}>) => {
        onError?.(e.nativeEvent as Error);
      },
      [onError],
    ) : undefined;

    const _onMessage = onMessage ? useCallback(
      (e: NativeSyntheticEvent<{}>) => {
        onMessage?.(e.nativeEvent);
      },
      [onMessage],
    ) : undefined;

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

    const _allowedTurboModules = [
      ...new Set([
        ...(allowedTurboModules ?? []),
        ...SANDBOX_TURBOMODULES_WHITELIST
      ])
    ];

    return (
      <View style={style}>
        <NativeComponent
          ref={nativeRef}
          onError={_onError}
          onMessage={_onMessage}
          allowedTurboModules={_allowedTurboModules}
          style={_style}
          {...rest} />
        {_renderOverlay()}
      </View>
    );
  },
);

SandboxReactNativeView.displayName = 'SandboxReactNativeView';
export default SandboxReactNativeView;