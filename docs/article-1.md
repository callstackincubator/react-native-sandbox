# Direct Communication Between React Native Sandbox Instances

**Authors**

Aliaksandr Babrykovich  
Senior C++ Engineer  
@ Callstack

---

## Introduction

In our previous article, we introduced [react-native-sandbox](https://www.callstack.com/blog/running-multiple-instances-of-react-native-in-sandbox) - a library that enables running multiple, isolated React Native instances within a single application. While the initial release focused on host-sandbox communication, we've now added a powerful new feature: **direct communication between sandbox instances**.

This enhancement opens up new possibilities for building complex multi-instance applications where sandboxes can communicate directly with each other, bypassing the host application entirely, while still maintaining the security.

## Understanding Communication Patterns

Before diving into the implementation, let's clarify the two communication patterns available in react-native-sandbox:

### Sandbox-Host-Sandbox - The Old Approach

This was the only way sandboxes could communicate with each other - through the host application acting as a message dispatcher. This approach came with  performance penalties and unnecessary boilerplate code.

This is the traditional communication pattern where sandboxes communicate through the host application:

```
Sandbox A → Host → Sandbox B
```

**Implementation Before Direct Communication Feature:**

```tsx
// Host application MUST handle message routing - there's no way around it
const handleMessage = (data: any) => {
  // Boilerplate routing logic that grows with each sandbox
  if (data.target === 'sandbox-b') {
    sandboxBRef.current?.postMessage(data.payload);
  } else if (data.target === 'sandbox-c') {
    sandboxCRef.current?.postMessage(data.payload);
  } else if (data.target === 'sandbox-d') {
    sandboxDRef.current?.postMessage(data.payload);
  }
  // ... more boilerplate for each additional sandbox
};

<SandboxReactNativeView 
  ref={sandboxARef}
  onMessage={handleMessage} 
/>
<SandboxReactNativeView 
  ref={sandboxBRef}
  onMessage={handleMessage} 
/>
<SandboxReactNativeView 
  ref={sandboxCRef}
  onMessage={handleMessage} 
/>
// ... more sandboxes = more boilerplate
```

This approach required constant maintenance of routing logic in the host application and created tight coupling between sandboxes and the host's message handling implementation.

### Sandbox-Sandbox - The New Approach

Sandboxes can now communicate directly with each other, eliminating the host-as-dispatcher pattern and all its associated problems.

This is the new direct communication pattern where sandboxes communicate directly:

```
Sandbox A ↔ Sandbox B
```

**Implementation with Direct Communication Feature:**

```tsx
// Host application - NO message routing needed!
export default function App() {
  return (
    <View style={styles.flexRow}>
      <View style={styles.flex10Margin}>
        <SandboxReactNativeView
          origin="A"
          jsBundleSource="sandbox"
          componentName="SandboxA"
          allowedOrigins={['B']} // Simple configuration
        />
      </View>
      
      <View style={styles.flex10Margin}>
        <SandboxReactNativeView
          origin="B"
          jsBundleSource="sandbox"
          componentName="SandboxB"
          allowedOrigins={['A']} // Simple configuration
        />
      </View>
    </View>
  );
}

// Sandbox A - Direct communication
const sendToB = () => {
  globalThis.postMessage({ type: 'increment', value: 1 }, 'B');
};

// Sandbox B - Direct communication  
const sendToA = () => {
  globalThis.postMessage({ type: 'decrement', value: 1 }, 'A');
};
```

With direct communication, sandboxes can send messages to each other without any involvement from the host. There’s no need for routing logic, no extra boilerplate, and no changes required in the host when adding new sandboxes. Just set the `allowedOrigins` prop, and sandboxes can communicate directly and efficiently.

## Security Model

Communication maintains the same security principles as the rest of react-native-sandbox:

### Origin-Based Access Control

Each sandbox explicitly declares which other sandboxes can send messages to it through the `allowedOrigins` prop:

```tsx
// Sandbox A allows messages from Sandbox B
allowedOrigins={['B']}

// Sandbox B allows messages from Sandbox A  
allowedOrigins={['A']}
```

### Bidirectional Control

Communication is not automatically bidirectional. If Sandbox A wants to send messages to Sandbox B, both conditions must be met:
1. Sandbox A's `allowedOrigins` includes 'B' (to send)
2. Sandbox B's `allowedOrigins` includes 'A' (to receive)

### Dynamic Permissions

The `allowedOrigins` can be updated at runtime, allowing for dynamic permission management:

```tsx
const [allowCommunication, setAllowCommunication] = useState(false);

<SandboxReactNativeView
  origin="A"
  allowedOrigins={allowCommunication ? ['B'] : []}
  // ... other props
/>
```

## API Reference

### Host-Side API

| Prop | Type | Description |
|------|------|-------------|
| `origin` | `string` | Unique identifier for the sandbox instance |
| `allowedOrigins` | `string[]` | Array of sandbox origins allowed to send messages |

### Sandbox-Side API

| Function | Parameters | Description |
|----------|------------|-------------|
| `globalThis.postMessage(message, targetOrigin)` | `message: any`, `targetOrigin: string` | Send message to specific sandbox |
| `globalThis.setOnMessage(handler)` | `handler: (payload: any) => void` | Register message handler |

## Demo time

[▶️ Watch the demo video](docs/videos/demo_1.mp4)

Check out the [`p2p-counter` example](https://github.com/callstackincubator/react-native-sandbox/tree/main/apps/p2p-counter), which demonstrates two sandboxes updating each other's state directly—no host routing required.

## Conclusion

Direct communication between React Native sandbox instances represents a significant evolution in the react-native-sandbox library. It provides developers with the flexibility to build complex, multi-instance applications with direct communication capabilities while maintaining the security and isolation benefits that make sandboxing valuable.

Whether you're building a micro-frontend dashboard, or a plugin system, direct sandbox communication enables new architectural patterns that were previously difficult to achieve with React Native.

To get started with direct sandbox communication, check out the [p2p-counter example](https://github.com/callstackincubator/react-native-sandbox/tree/main/apps/p2p-counter) and the [complete API documentation](https://github.com/callstackincubator/react-native-sandbox/blob/main/packages/react-native-sandbox/README.md#direct-communication-between-sandboxes).

---

**Ready to build secure, scalable multi-instance applications?**  
[Get started with react-native-sandbox](https://github.com/callstackincubator/react-native-sandbox)