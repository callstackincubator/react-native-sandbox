import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';

export interface Spec extends TurboModule {
  sendMessage(message: string, receiver: string): void;
  receiveMessage(callback: (message: string) => void): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>(
  'NativeMessanger',
);
