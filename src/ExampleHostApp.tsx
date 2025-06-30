import React, { useRef, useState } from 'react';
import { View, Dimensions, StyleSheet, SafeAreaView, Switch, NativeMethods, TouchableOpacity, Text, ColorValue } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  useDerivedValue,
} from 'react-native-reanimated';

import SandboxReactNativeView, {SandboxReactNativeViewRef} from './SandboxReactNativeView';
import Toast, { BaseToast, BaseToastProps, ToastConfigParams } from 'react-native-toast-message';
import { ViewProps } from '../ref-react-native/Libraries/Components/View/ViewPropTypes';

const { width: screenWidth, height: screenHeight } = Dimensions.get('window');
const BALL_SIZE = 50;

function SandboxDemoView({initialProperties}: {initialProperties: any}) {
  const [isSandboxEnabled, setSandboxEnabled] = useState(false);
  const sandboxRef = useRef<SandboxReactNativeViewRef>(null);
  
  return (
    <View style={{ flex: 1 }}>
      <SafeAreaView style={{ margin: 10, flex: 1 }}>
        <View style={styles.control}>
          <Switch value={isSandboxEnabled} onValueChange={() => setSandboxEnabled(v => !v)} />
          <TouchableOpacity style={styles.button} onPress={() => {
            sandboxRef?.current?.postMessage({date: new Date(), origin: "host"})
          }}>
            <Text style={styles.text}>Post</Text>
          </TouchableOpacity>
        </View>
        {isSandboxEnabled ? <SandboxReactNativeView
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
                                    props: {
                                      leftColor: initialProperties.backgroundColor,
                                    },
                                  });
                                }} /> : null}
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
        style={{
          borderLeftColor: props?.props.leftColor,
        }}
      />
    ),
  };

  return (
    <View style={styles.container}>
      <SandboxDemoView initialProperties={{sourceName: "green", backgroundColor: '#CCFFCC'}} />
      <SandboxDemoView initialProperties={{sourceName: "blue", backgroundColor: '#CCCCFF'}} />
      <BouncingBall />
      <Toast config={toastConfig} />
      
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
