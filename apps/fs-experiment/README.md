# File System Security Experiment

This React Native application demonstrates potential security vulnerabilities in multi-instance environments by testing file system access between the host app and sandboxed instances.

## 🎯 Purpose

This example tests whether sandboxed React Native instances can:
- Access files created by the host application
- Access files created by other sandbox instances  
- Modify or overwrite files from other instances
- Share storage space across different React Native instances

## 🔧 Dependencies

This example uses two popular React Native file system libraries:
- **react-native-fs** - Traditional file system operations
- **react-native-file-access** - Alternative file system API

## 📱 Features

### Host Application
- 🏠 Main app instance with full file system testing controls
- 📊 Real-time activity logs showing all file operations
- ⚠️ Security breach alerts when sandbox accesses host files
- 🏖️ Creates 3 sandbox instances for testing

### Sandbox Instances  
- 🏖️ Isolated React Native instances with same file system testing capabilities
- 🔍 Attempts to access host and other sandbox files
- 📝 Independent logging of file operations
- 🚨 Highlights potential security breaches

## 🧪 Test Scenarios

### 1. Basic File Operations
- Create, read, write files in documents directory
- List directory contents
- Test both RNFS and FileAccess APIs

### 2. Cross-Instance File Access
- Host tries to read sandbox files
- Sandbox tries to read host files
- Sandbox tries to read other sandbox files

### 3. File Modification Attacks
- Sandbox attempts to overwrite host files
- Sandbox attempts to modify other sandbox files
- Detection of successful unauthorized modifications

## 🚨 Security Implications

This experiment reveals whether:
- File system storage is properly isolated between instances
- One instance can compromise data from another
- Malicious sandbox code could affect the host application
- Cross-sandbox communication is possible via shared files

## 🚀 Running the Example

1. Install dependencies:
   ```bash
   cd apps/fs-experiment
   bun install
   ```

2. Install native dependencies:
   ```bash
   cd ios && pod install && cd ..
   ```

3. Run the application:
   ```bash
   # iOS
   bun ios
   
   # Android  
   bun android
   ```

## 📊 Understanding the Results

- ✅ **Green messages**: Proper isolation working (cannot access other files)
- 🚨 **Red messages**: Security breach detected (unauthorized file access)
- 📝 **Regular logs**: Normal file operations within instance scope

## ⚠️ Expected vs Concerning Behavior

### Expected (Secure) Behavior:
- Each instance can only access its own files
- Cross-instance file access should fail
- File modification across instances should be blocked

### Concerning (Insecure) Behavior:
- Sandbox can read host application files
- Sandbox can modify host application files
- Sandbox instances can access each other's files
- Shared storage without proper isolation

## 🔧 Technical Details

The experiment uses:
- Document directory for persistent file storage
- Unique file names per instance (`test_${sandboxId}.txt`)
- Both sync and async file operations
- Directory listing to discover other instance files
- Deliberate cross-instance access attempts

This test helps identify whether the multi-instance architecture properly isolates file system access or if additional security measures are needed.
