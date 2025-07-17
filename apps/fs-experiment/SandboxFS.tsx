import React, { useState } from 'react';
import {
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
  useColorScheme,
  Platform,
} from 'react-native';

// File system import
import RNFS from 'react-native-fs';

const SHARED_FILE_PATH = `${RNFS.DocumentDirectoryPath}/shared_test_file.txt`;

function SandboxFS(): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  const [textContent, setTextContent] = useState<string>('');
  const [status, setStatus] = useState<string>('Ready');

  const theme = {
    background: isDarkMode ? '#000000' : '#ffffff',
    surface: isDarkMode ? '#1c1c1e' : '#f2f2f7',
    primary: isDarkMode ? '#ff6b35' : '#ff6b35',
    secondary: isDarkMode ? '#34c759' : '#34c759',
    text: isDarkMode ? '#ffffff' : '#000000',
    textSecondary: isDarkMode ? '#8e8e93' : '#3c3c43',
    border: isDarkMode ? '#38383a' : '#c6c6c8',
    success: '#34c759',
    error: '#ff3b30',
    warning: '#ff9500',
  };

  const writeFile = async () => {
    try {
      setStatus('Writing file...');
      await RNFS.writeFile(SHARED_FILE_PATH, textContent, 'utf8');
      setStatus(`Successfully wrote: "${textContent}"`);
    } catch (error) {
      setStatus(`Write error: ${(error as Error).message}`);
    }
  };

  const readFile = async () => {
    try {
      setStatus('Reading file...');
      const content = await RNFS.readFile(SHARED_FILE_PATH, 'utf8');
      setTextContent(content);
      if (content.includes('Host')) {
        setStatus(`SECURITY BREACH: Read host file: "${content}"`);
      } else {
        setStatus(`Successfully read: "${content}"`);
      }
    } catch (error) {
      setStatus(`Read error: ${(error as Error).message}`);
    }
  };

  const getStatusStyle = () => {
    if (status.includes('SECURITY BREACH')) {
      return { color: theme.error, fontWeight: '600' as const };
    }
    if (status.includes('error')) {
      return { color: theme.error };
    }
    if (status.includes('Successfully')) {
      return { color: theme.success };
    }
    return { color: theme.textSecondary };
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: theme.background }]}>
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        showsVerticalScrollIndicator={false}>

        {/* Header */}
        <View style={[styles.header, { backgroundColor: theme.surface }]}>
          <View style={styles.headerContent}>
            <Text style={[styles.title, { color: theme.text }]}>
              Sandbox Environment
            </Text>
            <View style={[styles.badge, { backgroundColor: theme.primary }]}>
              <Text style={styles.badgeText}>RNFS</Text>
            </View>
          </View>
          <Text style={[styles.subtitle, { color: theme.textSecondary }]}>
            React Native File System Implementation
          </Text>
        </View>

        <View style={styles.content}>
          <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.border }]}>
            <Text style={[styles.sectionTitle, { color: theme.text }]}>
              File Operations
            </Text>

            <TextInput
              style={[styles.textInput, {
                color: theme.text,
                backgroundColor: theme.background,
                borderColor: theme.border,
              }]}
              value={textContent}
              onChangeText={setTextContent}
              placeholder="Enter text content..."
              placeholderTextColor={theme.textSecondary}
              multiline
            />

            <View style={styles.buttonGroup}>
              <TouchableOpacity
                style={[styles.button, { backgroundColor: theme.primary }]}
                onPress={writeFile}>
                <Text style={styles.buttonText}>Write</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.button, { backgroundColor: theme.secondary }]}
                onPress={readFile}>
                <Text style={styles.buttonText}>Read</Text>
              </TouchableOpacity>
            </View>

            <View style={[styles.statusContainer, { backgroundColor: theme.background }]}>
              <Text style={[styles.statusLabel, { color: theme.textSecondary }]}>
                Operation Status:
              </Text>
              <Text style={[styles.statusText, getStatusStyle()]}>
                {status}
              </Text>
            </View>

            <View style={[styles.pathContainer, { backgroundColor: theme.background }]}>
              <Text style={[styles.pathLabel, { color: theme.textSecondary }]}>
                Target Path:
              </Text>
              <Text style={[styles.pathText, { color: theme.textSecondary }]}>
                {SHARED_FILE_PATH}
              </Text>
            </View>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 16,
    paddingVertical: 20,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.1,
        shadowRadius: 4,
      },
      android: {
        elevation: 2,
      },
    }),
  },
  headerContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    flex: 1,
  },
  subtitle: {
    fontSize: 14,
    fontWeight: '400',
  },
  badge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
  },
  badgeText: {
    color: '#ffffff',
    fontSize: 11,
    fontWeight: '600',
    textTransform: 'uppercase',
  },
  content: {
    padding: 16,
  },
  card: {
    borderRadius: 12,
    padding: 20,
    borderWidth: 1,
    ...Platform.select({
      ios: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 8,
      },
      android: {
        elevation: 3,
      },
    }),
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 16,
  },
  textInput: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 14,
    marginBottom: 16,
    minHeight: 80,
    textAlignVertical: 'top',
    fontSize: 15,
    lineHeight: 20,
  },
  buttonGroup: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 16,
  },
  button: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  buttonText: {
    color: '#ffffff',
    fontWeight: '600',
    fontSize: 15,
  },
  statusContainer: {
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
  },
  statusLabel: {
    fontSize: 13,
    fontWeight: '500',
    marginBottom: 4,
  },
  statusText: {
    fontSize: 13,
    fontStyle: 'italic',
    lineHeight: 18,
  },
  pathContainer: {
    padding: 12,
    borderRadius: 8,
  },
  pathLabel: {
    fontSize: 11,
    fontWeight: '500',
    marginBottom: 4,
    textTransform: 'uppercase',
  },
  pathText: {
    fontSize: 10,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    opacity: 0.8,
    lineHeight: 14,
  },
});

export default SandboxFS;
