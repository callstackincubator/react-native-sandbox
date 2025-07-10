import React, { useRef, useState } from 'react';
import { Button, View, Dimensions, StyleSheet, SafeAreaView, Switch, TouchableOpacity, Text, ColorValue, ViewStyle } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  useDerivedValue,
} from 'react-native-reanimated';

import SandboxReactNativeView, {SandboxReactNativeViewRef} from 'react-native-multinstance';
import Toast, { BaseToast, ToastConfigParams } from 'react-native-toast-message';

const { width: screenWidth, height: screenHeight } = Dimensions.get('window');
const BALL_SIZE = 50;

function SandboxDemoView({initialProperties}: {initialProperties: any}) {
  const [isVisible, setVisible] = useState(false);
  const sandboxRef = useRef<SandboxReactNativeViewRef>(null);
  
  return (
    <View style={{ flex: 1 }}>
      <SafeAreaView style={{ margin: 10, flex: 1 }}>
        <View style={styles.control}>
          <Switch value={isVisible} onValueChange={() => setVisible(v => !v)} />
          <Button color={styles.button.backgroundColor} title="Post message" onPress={() => {
            sandboxRef?.current?.postMessage({date: new Date().toJSON(), origin: "host"})
          }} />
        </View>
        {isVisible ?
          <SandboxReactNativeView
            ref={sandboxRef}
            jsBundleName={"sandbox"}
            moduleName={"SandboxApp"}
            style={{flex: 1, padding: 30}}
            initialProperties={initialProperties}
            onMessage={(msg) => {
              console.log(`Got message from ${initialProperties.sourceName}`, msg);
              Toast.show({
                type: 'customColored',
                text1: initialProperties.sourceName,
                text2: JSON.stringify(msg),
                visibilityTime: 5000,
                props: {
                  leftColor: initialProperties.backgroundColor,
                },
              });
            }}
            onError={error => {
              const isFatal = error.isFatal;
              const message = `Got ${isFatal ? 'fatal' : 'non-fatal'} error from ${initialProperties.sourceName}`;
              console.warn(message, error);
              Toast.show({
                type: 'error',
                text1: message,
                text2: `${error.name}: ${error.message}`,
                visibilityTime: 5000
              })
              return false;
            }}
            /> : null
          }
      </SafeAreaView>
    </View>
  );
}

function BouncingBall() {
  // Position and velocity shared values  
  const ballX = useSharedValue(50);
  const ballY = useSharedValue(50);
  const velocityX = useSharedValue(6);
  const velocityY = useSharedValue(6);

  // Animation loop using derived value for continuous movement  
  useDerivedValue(() => {
    // Update position  
    ballX.value += velocityX.value;
    ballY.value += velocityY.value;

    // Bounce off walls  
    if (ballX.value <= 0 || ballX.value >= screenWidth - BALL_SIZE) {
      velocityX.value *= -1;
      ballX.value = Math.max(0, Math.min(screenWidth - BALL_SIZE, ballX.value));
    }

    if (ballY.value <= 0 || ballY.value >= screenHeight - BALL_SIZE) {
      velocityY.value *= -1;
      ballY.value = Math.max(0, Math.min(screenHeight - BALL_SIZE, ballY.value));
    }
  });

  // Animated style for the ball  
  const animatedStyle = useAnimatedStyle(() => {
    return {
      transform: [
        { translateX: ballX.value },
        { translateY: ballY.value },
      ],
    };
  });

  return (
    <Animated.View style={[styles.ball, animatedStyle]} />
  );
}

export default function App() {
  const toastConfig = {
    customColored: (props: ToastConfigParams<{leftColor: ColorValue}>) => (
      <BaseToast
        {...props}
        text2NumberOfLines={0}
        style={{
          borderLeftColor: props?.props.leftColor,
        }}
      />
    ),
  };

  return (
    <SafeAreaView style={styles.container}>
      <SandboxDemoView initialProperties={{sourceName: "green", backgroundColor: '#CCFFCC'}} />
      <SandboxDemoView initialProperties={{sourceName: "blue", backgroundColor: '#CCCCFF'}} />
      <BouncingBall />
      <Toast config={toastConfig} />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    flexDirection: 'column',
  },
  ball: {
    width: BALL_SIZE,
    height: BALL_SIZE,
    borderRadius: BALL_SIZE / 2,
    backgroundColor: '#ff9b9b',
    position: 'absolute',
  },
  control: {
    alignSelf: 'center',
    margin: 5,
    flexDirection: 'row',
    justifyContent: 'space-evenly',
    padding: 5,
  },
  button: {
    padding: 10,
    backgroundColor: '#007AFF',
    borderRadius: 8,
    alignItems: 'center',
  },
  text: {
    color: 'white',
    fontSize: 16,
  },
});
