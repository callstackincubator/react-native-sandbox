import {TurboModule, TurboModuleRegistry} from 'react-native';

type Payload = unknown;

export interface Spec extends TurboModule {
  readonly registerRuntime: (name: string, processor: (payload: Payload) => void) => void;
  readonly sendToRuntime: (name: string, payload: Payload) => void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('IPCTurboModule');
