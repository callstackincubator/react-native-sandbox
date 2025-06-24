import {TurboModule, TurboModuleRegistry} from 'react-native';

type Payload = unknown;

export interface Spec extends TurboModule {
  readonly registerRuntime: (name: string, processor: (payload: Payload) => void) => void;
  readonly postMessage: (name: string, payload: Payload) => void;
}

const NativeMultiReactMediator = TurboModuleRegistry.getEnforcing<Spec>('MultiReactMediatorModule');

export default NativeMultiReactMediator;

(globalThis as any).postMessage = (message: any, targetOrigin: string) => NativeMultiReactMediator.postMessage(targetOrigin, message);