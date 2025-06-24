import React, { Component, useEffect, useRef, useState } from 'react';
import { View, Dimensions, StyleSheet, SafeAreaView, Switch, NativeMethods, TouchableOpacity, Text } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  useDerivedValue,
} from 'react-native-reanimated';

import SandboxReactNativeView, {SandboxReactNativeViewRef} from './SandboxReactNativeView';

const { width: screenWidth, height: screenHeight } = Dimensions.get('window');
const BALL_SIZE = 50;

export default function BouncingBallScreen() {
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

  const [isSandbox1Enabled, setSandbox1Enabled] = useState(false);
  const [isSandbox2Enabled, setSandbox2Enabled] = useState(false);

  const sandbox1Ref = useRef<SandboxReactNativeViewRef | null>(null);
  const sandbox2Ref = useRef<SandboxReactNativeViewRef | null>(null);

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
    <View style={styles.container}>
      <View style={{ backgroundColor: '#CCFFCC', flex: 1 }}>
        <SafeAreaView style={{ margin: 10, flex: 1 }}>
          <View style={styles.control}>
            <Switch value={isSandbox1Enabled} onValueChange={() => setSandbox1Enabled(v => !v)} />
            <TouchableOpacity style={styles.button} onPress={() => {
              sandbox1Ref?.current?.postMessage({counter: 1, date: new Date(), origin: "host"})
            }}>
              <Text style={styles.text}>Post</Text>
            </TouchableOpacity>
          </View>
          {isSandbox1Enabled ? <SandboxReactNativeView
                                  ref={sandbox1Ref}
                                  jsBundleName={"sandbox"}
                                  moduleName={"SandboxApp"}
                                  style={{flex: 1}}
                                  initialProperties={{sourceName: "green", backgroundColor: '#CCFFCC'}}
                                  onMessage={(msg) => {
                                    console.log("Got message from sandbox1", msg)
                                  }} /> : null}
        </SafeAreaView>
      </View>
      <View style={{ backgroundColor: '#CCCCFF', flex: 1 }}>
        <SafeAreaView style={{ margin: 10, flex: 1 }}>
          <View style={styles.control}>
            <Switch value={isSandbox2Enabled} onValueChange={() => setSandbox2Enabled(v => !v)} />
            <TouchableOpacity style={styles.button} onPress={() => sandbox2Ref?.current?.postMessage({counter: 1, date: new Date(), origin: "host"})}>
              <Text style={styles.text}>Post</Text>
            </TouchableOpacity>
          </View>
          {isSandbox2Enabled ? <SandboxReactNativeView
                                  ref={sandbox2Ref}
                                  jsBundleName={"sandbox"}
                                  moduleName={"SandboxApp"}
                                  style={{flex: 1}}
                                  initialProperties={{sourceName: "blue", backgroundColor: '#CCCCFF'}}
                                  onMessage={(msg) => {
                                    console.log("Got message from sandbox2", msg)
                                  }} /> : null}
        </SafeAreaView>
      </View>
      <Animated.View style={[styles.ball, animatedStyle]} />
    </View>
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
