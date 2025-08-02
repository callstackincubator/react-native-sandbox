# @callstack/react-native-sandbox

[![npm version](https://badge.fury.io/js/@callstack%2Freact-native-sandbox.svg)](https://badge.fury.io/js/@callstack%2Freact-native-sandbox)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/callstackincubator/react-native-sandbox/blob/main/LICENSE)

> **Library Documentation** - For project overview, examples, and security considerations, see the [main repository README](https://github.com/callstackincubator/react-native-sandbox#readme).

This is the **developer documentation** for installing and using `@callstack/react-native-sandbox` in your React Native application.

## 📦 Installation

### npm/yarn

```bash
npm install @callstack/react-native-sandbox
# or
yarn add @callstack/react-native-sandbox
```

### iOS Setup

The package uses **autolinking** and supports the **React Native New Architecture** - no manual configuration required.

### Android Setup

> 🚧 **Under Construction** - Android support is currently in development. Stay tuned for updates!

## 🎯 Basic Usage

> For complete examples with both host and sandbox code, see the [project examples](https://github.com/callstackincubator/react-native-sandbox#-api-example).

```tsx
import SandboxReactNativeView from '@callstack/react-native-sandbox';

<SandboxReactNativeView
  componentName="YourSandboxComponent" // Name of component registered in bundle provided with jsBundleSource
  jsBundleSource="sandbox" // bundle file name
  onMessage={(data) => console.log('From sandbox:', data)}
  onError={(error) => console.error('Sandbox error:', error)}
/>
```

## 📚 API Reference

### Component Props

| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| `componentName` | `string` | :ballot_box_with_check: | - | Name of the component registered through `AppRegistry.registerComponent` call inside the bundle file specified in `jsBundleSource` |
| `moduleName` | `string` | :white_large_square: | - | **⚠️ Deprecated**: Use `componentName` instead. Will be removed in a future version. |
| `jsBundleSource` | `string` | :ballot_box_with_check: | - | Name on file storage or URL to the JavaScript bundle to load |
| `initialProperties` | `object` | :white_large_square: | `{}` | Initial props for the sandboxed app |
| `launchOptions` | `object` | :white_large_square: | `{}` | Launch configuration options |
| `allowedTurboModules` | `string[]` | :white_large_square: | [check here](https://github.com/callstackincubator/react-native-sandbox/blob/main/packages/react-native-sandbox/src/index.tsx#L18) | Additional TurboModules to allow |
| `onMessage` | `function` | :white_large_square: | `undefined` | Callback for messages from sandbox |
| `onError` | `function` | :white_large_square: | `undefined` | Callback for sandbox errors |
| `style` | `ViewStyle` | :white_large_square: | `undefined` | Container styling |

### Ref Methods

```tsx
interface SandboxReactNativeViewRef {
  postMessage: (message: unknown) => void;
}
```

### Error Event Structure

```tsx
interface ErrorEvent {
  name: string;        // Error type (e.g., 'TypeError')
  message: string;     // Error description
  stack?: string;      // Stack trace
  isFatal?: boolean;   // Whether error crashed the sandbox
}
```

## 🔒 Security & TurboModules

> For detailed security considerations, see the [Security section](https://github.com/callstackincubator/react-native-sandbox#-security-considerations) in the main README.

This package is built with **React Native New Architecture** using Fabric for optimal performance and type safety.

### TurboModule Filtering

Use `allowedTurboModules` to control which native modules the sandbox can access:

```tsx
<SandboxReactNativeView
  allowedTurboModules={['MyTrustedModule', 'AnotherSafeModule']}
  // ... other props
/>
```

**Default allowed modules** include essential React Native TurboModules like `EventDispatcher`, `AppState`, `Networking`, etc. See the [source code](https://github.com/callstackincubator/react-native-sandbox/blob/main/packages/react-native-sandbox/src/index.tsx) for the complete list.

> Note: This filtering works with both legacy native modules and new TurboModules, ensuring compatibility across React Native versions.

## 💬 Communication Patterns

### Message Types

```tsx
// Configuration updates
sandboxRef.current?.postMessage({
  type: 'config',
  payload: { theme: 'dark', locale: 'en' }
});

// Action commands  
sandboxRef.current?.postMessage({
  type: 'action',
  action: 'refresh'
});

// Data synchronization
sandboxRef.current?.postMessage({
  type: 'data',
  data: { users: [], posts: [] }
});
```

### Message Validation

```tsx
const handleMessage = (data: unknown) => {
  // Always validate messages from sandbox
  if (!data || typeof data !== 'object') return;
  
  const message = data as { type?: string; payload?: unknown };
  
  switch (message.type) {
    case 'ready':
      console.log('Sandbox is ready');
      break;
    case 'request':
      ref?.current.postMessage({requested: 'data'});
      break;
    default:
      console.warn('Unknown message type:', message.type);
  }
};
```

## 🎨 Advanced Usage

### Dynamic Bundle Loading

```tsx
const [bundleUrl, setBundleUrl] = useState<string>();

// Load bundle URL from your backend
useEffect(() => {
  fetch('/api/sandbox-config')
    .then(res => res.json())
    .then(config => setBundleUrl(config.bundleUrl));
}, []);

return (
  <SandboxReactNativeView
    componentName="DynamicApp" // Name of component registered in bundle provided with jsBundleSource
    jsBundleSource={bundleUrl}
    initialProperties={{ 
      userId: currentUser.id,
      theme: userPreferences.theme 
    }}
  />
);
```

### Performance Monitoring

```tsx
const handleMessage = (data: unknown) => {
  // Monitor sandbox performance metrics
  if (data?.type === 'performance') {
    console.log('Sandbox metrics:', data.metrics);
  }
};
```

## ⚡ Performance & Best Practices

### Memory Management

- Each sandbox creates a separate JavaScript context
- Use `key` prop to force re-mount when needed
- Monitor memory usage in production

### Communication Efficiency

```tsx
// ✅ Good: Batch updates
const batchedData = { users, posts, notifications };
sandboxRef.current?.postMessage({ type: 'batch_update', data: batchedData });

// ❌ Avoid: Frequent individual messages
users.forEach(user => sandboxRef.current?.postMessage({ type: 'user', user }));
```

## 🔧 Troubleshooting

### Common Issues

**1. Bundle Loading Fails**
```tsx
// ❌ Invalid bundle source
jsBundleSource="/invalid/path.js"

// ✅ Correct bundle source
jsBundleSource="https://cdn.example.com/app.bundle.js"
// or
jsBundleSource="micro-app.jsbundle"
```

**2. TurboModule Access Denied**
```tsx
// ❌ Module not in whitelist
// Error: TurboModule 'MyModule' is not allowed

// ✅ Add to allowed list
allowedTurboModules={['MyModule']}
```

**3. Fatal Error Recovery**
```tsx
// ❌ Sandbox crashed and won't recover
<SandboxReactNativeView
  onError={(error) => {
    console.log('Error:', error);
    // Sandbox remains broken after fatal error
  }}
/>

// ✅ Auto-recover from fatal errors by re-mounting
const [sandboxKey, setSandboxKey] = useState(0);

const handleError = (error: ErrorEvent) => {
  if (error.isFatal) {
    // Force re-mount to recover from fatal errors
    setSandboxKey(prev => prev + 1);
  }
};

<SandboxReactNativeView
  key={sandboxKey} // Re-mount on fatal errors
  componentName={"SandboxedApp"} // Name of component registered in bundle provided with jsBundleSource
  jsBundleSource={"sandbox"}
  onError={handleError}
/>
```

**4. Bundle Size Performance Issues**
```tsx
// ❌ Avoid: Large monolithic bundles (slow loading)
jsBundleSource="entire-app-with-everything.bundle.js"

// ✅ Good: Small, focused bundles (fast loading)
jsBundleSource="micro-app-dashboard.bundle.js"
// or
jsBundleSource="https://cdn.example.com/lightweight-feature.bundle.js"
```

## 📄 More Information

- **📖 Project Overview & Examples**: [Main README](https://github.com/callstackincubator/react-native-sandbox#readme)
- **🔒 Security Considerations**: [Security Documentation](https://github.com/callstackincubator/react-native-sandbox#-security-considerations)
- **🎨 Roadmap**: [Development Plans](https://github.com/callstackincubator/react-native-sandbox#-roadmap)
- **🐛 Issues**: [GitHub Issues](https://github.com/callstackincubator/react-native-sandbox/issues)