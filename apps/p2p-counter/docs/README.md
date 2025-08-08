# P2P Counter App Documentation

## Overview

The P2P Counter app demonstrates peer-to-peer communication between two sandboxed React Native views. Each sandbox contains a counter application with two counters and increment buttons.

## Features

### Sandbox Components
- **This Counter**: Local counter that can be incremented independently
- **That Counter**: Remote counter that can be incremented and synchronized
- **Increment Buttons**: "Increment This" and "Increment That" buttons
- **Origin Display**: Shows which origins are allowed to send messages

### Communication Controls
- **A → B Switch**: Enables/disables communication from Sandbox A to Sandbox B
- **B → A Switch**: Enables/disables communication from Sandbox B to Sandbox A

### UI Elements
- **Header**: App title and description
- **Side-by-side Sandboxes**: Two sandboxed views (A and B)
- **Control Panel**: Switches for communication control
- **Bouncing Ball**: Animated element demonstrating non-interference

## How It Works

1. **Initial State**: Both sandboxes start with counters at 0
2. **Local Increments**: "Increment This" buttons work independently in each sandbox
3. **Remote Increments**: "Increment That" buttons send messages to the other sandbox
4. **Communication Control**: Switches control which sandbox can send messages to the other
5. **Real-time Sync**: Counter values update in real-time when communication is enabled

## Message Flow

```
Sandbox A "Increment That" → Host App → Sandbox B (if A→B enabled)
Sandbox B "Increment That" → Host App → Sandbox A (if B→A enabled)
```

## Usage Examples

### Basic Operation
1. Launch the app
2. Both sandboxes display counters at 0
3. Use "Increment This" to increment local counters
4. Use "Increment That" to send increment events to the other sandbox

### Communication Control
1. **Enable A→B**: Sandbox A can send "Increment That" events to Sandbox B
2. **Enable B→A**: Sandbox B can send "Increment That" events to Sandbox A
3. **Disable both**: Each sandbox operates independently

### Testing Scenarios
- **Independent Mode**: Disable both switches, increment counters independently
- **One-way Communication**: Enable only A→B or B→A
- **Two-way Communication**: Enable both switches for full synchronization

## Technical Details

### Architecture
- **Host App**: Manages two sandbox instances and communication routing
- **Sandbox Apps**: Isolated React Native views with counter logic
- **Message System**: JSON-based communication via the sandbox library
- **State Management**: React state for counters and communication settings

### Dependencies
- `@callstack/react-native-sandbox`: Sandbox isolation
- `react-native-reanimated`: Animations
- `react-native-toast-message`: Message notifications

### Files
- `App.tsx`: Main host application
- `sandbox.js`: Counter app running in sandboxes
- `index.js`: App registration
- `package.json`: Dependencies and scripts

## Running the App

```bash
# Install dependencies
bun install

# Run on iOS
bun run ios --filter=@apps/p2p-counter

# Run on Android
bun run android --filter=@apps/p2p-counter
```

## Troubleshooting

### Common Issues
1. **Counters not syncing**: Check that communication switches are enabled
2. **App not building**: Ensure all dependencies are installed with `bun install`
3. **TypeScript errors**: Run `bun run typecheck` to verify types

### Debug Tips
- Check console logs for message flow
- Use toast notifications to see message content
- Verify sandbox isolation by testing independent operation 