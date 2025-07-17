import React from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';

import {
  Colors,
  DebugInstructions,
  Header,
  LearnMoreLinks,
  ReloadInstructions,
} from 'react-native/Libraries/NewAppScreen';

import SandboxReactNativeView from 'react-native-multinstance';

const MAX_DEPTH = 5;

type SectionProps = {
  children: React.ReactNode;
  title: string;
  depth: number;
};

function Section({ children, title, depth }: SectionProps): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  return (
    <View style={styles.sectionContainer}>
      <Text
        style={[
          styles.sectionTitle,
          {
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 26 - depth * 3,
          },
        ]}>
        {title}
      </Text>
      <Text
        style={[
          styles.sectionDescription,
          {
            color: isDarkMode ? Colors.light : Colors.dark,
            fontSize: 20 - depth * 3,
          },
        ]}>
        {children}
      </Text>
    </View>
  );
}

interface AppProps {
  depth?: number;
}

function App({ depth = 1 }: AppProps): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  const colors = ['#FF0000', '#00FF00', '#0000FF', '#FFFF00', '#00FFFF'];
  const borderColor = colors[depth - 1] || 'gray';

  return (
    <SafeAreaView style={backgroundStyle}>
      <StatusBar
        barStyle={isDarkMode ? 'light-content' : 'dark-content'}
        backgroundColor={backgroundStyle.backgroundColor}
      />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}>
        <Header />
        <View
          style={[
            {
              backgroundColor: isDarkMode ? Colors.black : Colors.white,
              borderColor: borderColor,
            },
            depth > 1 && styles.nestedContainer,
          ]}>
          <Section title={`Recursive Sandbox (Depth: ${depth})`} depth={depth}>
            This is a nested React Native instance.
          </Section>
          {depth < MAX_DEPTH ? (
            <View style={styles.recursiveSandboxContainer}>
              <Text style={styles.recursiveSandboxTitle}>Next Level (Depth: {depth + 1})</Text>
              <SandboxReactNativeView
                style={styles.recursiveSandbox}
                moduleName="App" // Recursively load App itself
                initialProperties={{ depth: depth + 1 }}
              />
            </View>
          ) : (
            <Section title="Max Depth Reached!" depth={depth}>
              No more nested instances will be created.
            </Section>
          )}
          <Section title="See Your Changes" depth={depth}>
            <ReloadInstructions />
          </Section>
          <Section title="Debug" depth={depth}>
            <DebugInstructions />
          </Section>
          <Section title="Learn More" depth={depth}>
            Read the docs to discover what to do next:
          </Section>
          <LearnMoreLinks />
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontWeight: '600',
  },
  sectionDescription: {
    marginTop: 8,
    fontWeight: '400',
  },
  highlight: {
    fontWeight: '700',
  },
  nestedContainer: {
    borderWidth: 2,
    margin: 5,
    padding: 5,
  },
  recursiveSandboxContainer: {
    marginTop: 20,
    height: 500,
    borderWidth: 1,
    borderColor: 'gray',
    marginHorizontal: 24,
    marginBottom: 20,
  },
  recursiveSandboxTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    textAlign: 'center',
    padding: 10,
    color: 'black',
  },
  recursiveSandbox: {
    flex: 1,
  },
});

export default App;
