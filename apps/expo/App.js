import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React, {useCallback, useState} from 'react'
import {
  SafeAreaView,
  StatusBar,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'

const CounterApp = () => {
  const [count, setCount] = useState(0)

  const handleMessage = useCallback(message => {
    console.log('Counter app received message:', message)
    if (message.type === 'INCREMENT') {
      setCount(prev => prev + 1)
    } else if (message.type === 'DECREMENT') {
      setCount(prev => prev - 1)
    }
  }, [])

  const sendMessage = useCallback(type => {
    // This would send a message to other sandboxes
    console.log('Sending message:', type)
  }, [])

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Counter App</Text>
      <Text style={styles.count}>Count: {count}</Text>
      <View style={styles.buttonContainer}>
        <TouchableOpacity
          style={styles.button}
          onPress={() => setCount(prev => prev + 1)}>
          <Text style={styles.buttonText}>+</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.button}
          onPress={() => setCount(prev => prev - 1)}>
          <Text style={styles.buttonText}>-</Text>
        </TouchableOpacity>
      </View>
      <View style={styles.messageContainer}>
        <TouchableOpacity
          style={styles.messageButton}
          onPress={() => sendMessage('INCREMENT')}>
          <Text style={styles.messageButtonText}>Send Increment</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.messageButton}
          onPress={() => sendMessage('DECREMENT')}>
          <Text style={styles.messageButtonText}>Send Decrement</Text>
        </TouchableOpacity>
      </View>
    </View>
  )
}

const CalculatorApp = () => {
  const [display, setDisplay] = useState('0')
  const [operation, setOperation] = useState(null)
  const [firstNumber, setFirstNumber] = useState(null)

  const handleNumber = useCallback(
    num => {
      if (display === '0') {
        setDisplay(num)
      } else {
        setDisplay(display + num)
      }
    },
    [display]
  )

  const handleOperation = useCallback(
    op => {
      setFirstNumber(parseFloat(display))
      setOperation(op)
      setDisplay('0')
    },
    [display]
  )

  const calculate = useCallback(() => {
    if (operation && firstNumber !== null) {
      const secondNumber = parseFloat(display)
      let result
      switch (operation) {
        case '+':
          result = firstNumber + secondNumber
          break
        case '-':
          result = firstNumber - secondNumber
          break
        case '*':
          result = firstNumber * secondNumber
          break
        case '/':
          result = firstNumber / secondNumber
          break
        default:
          return
      }
      setDisplay(result.toString())
      setOperation(null)
      setFirstNumber(null)
    }
  }, [operation, firstNumber, display])

  const clear = useCallback(() => {
    setDisplay('0')
    setOperation(null)
    setFirstNumber(null)
  }, [])

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Calculator</Text>
      <Text style={styles.display}>{display}</Text>
      <View style={styles.calculatorGrid}>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('7')}>
          <Text style={styles.calcButtonText}>7</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('8')}>
          <Text style={styles.calcButtonText}>8</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('9')}>
          <Text style={styles.calcButtonText}>9</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleOperation('+')}>
          <Text style={styles.calcButtonText}>+</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('4')}>
          <Text style={styles.calcButtonText}>4</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('5')}>
          <Text style={styles.calcButtonText}>5</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('6')}>
          <Text style={styles.calcButtonText}>6</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleOperation('-')}>
          <Text style={styles.calcButtonText}>-</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('1')}>
          <Text style={styles.calcButtonText}>1</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('2')}>
          <Text style={styles.calcButtonText}>2</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('3')}>
          <Text style={styles.calcButtonText}>3</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleOperation('*')}>
          <Text style={styles.calcButtonText}>×</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('0')}>
          <Text style={styles.calcButtonText}>0</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleNumber('.')}>
          <Text style={styles.calcButtonText}>.</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.calcButton} onPress={calculate}>
          <Text style={styles.calcButtonText}>=</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.calcButton}
          onPress={() => handleOperation('/')}>
          <Text style={styles.calcButtonText}>÷</Text>
        </TouchableOpacity>
      </View>
      <TouchableOpacity style={styles.clearButton} onPress={clear}>
        <Text style={styles.clearButtonText}>Clear</Text>
      </TouchableOpacity>
    </View>
  )
}

export default function App() {
  const [activeSandbox, setActiveSandbox] = useState('counter')

  return (
    <SafeAreaView style={styles.safeArea}>
      <StatusBar barStyle="dark-content" backgroundColor="#f0f0f0" />
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Expo Sandbox Demo</Text>
        <View style={styles.tabContainer}>
          <TouchableOpacity
            style={[
              styles.tab,
              activeSandbox === 'counter' && styles.activeTab,
            ]}
            onPress={() => setActiveSandbox('counter')}>
            <Text
              style={[
                styles.tabText,
                activeSandbox === 'counter' && styles.activeTabText,
              ]}>
              Counter
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.tab,
              activeSandbox === 'calculator' && styles.activeTab,
            ]}
            onPress={() => setActiveSandbox('calculator')}>
            <Text
              style={[
                styles.tabText,
                activeSandbox === 'calculator' && styles.activeTabText,
              ]}>
              Calculator
            </Text>
          </TouchableOpacity>
        </View>
      </View>

      <View style={styles.content}>
        {activeSandbox === 'counter' ? (
          <SandboxReactNativeView
            componentName="CounterApp"
            origin="counter-sandbox"
            allowedTurboModules={[
              'AppState',
              'DeviceInfo',
              'PlatformConstants',
            ]}
            onMessage={console.log}
            onError={console.error}
            style={styles.sandbox}
          />
        ) : (
          <SandboxReactNativeView
            componentName="CalculatorApp"
            origin="calculator-sandbox"
            allowedTurboModules={[
              'AppState',
              'DeviceInfo',
              'PlatformConstants',
            ]}
            onMessage={console.log}
            onError={console.error}
            style={styles.sandbox}
          />
        )}
      </View>
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#f0f0f0',
  },
  header: {
    backgroundColor: '#ffffff',
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
    color: '#333',
  },
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: '#f0f0f0',
    borderRadius: 8,
    padding: 4,
  },
  tab: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 6,
    alignItems: 'center',
  },
  activeTab: {
    backgroundColor: '#ffffff',
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 1},
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  tabText: {
    fontSize: 16,
    fontWeight: '500',
    color: '#666',
  },
  activeTabText: {
    color: '#007AFF',
  },
  content: {
    flex: 1,
    padding: 20,
  },
  sandbox: {
    flex: 1,
    backgroundColor: '#ffffff',
    borderRadius: 12,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  // Counter App Styles
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#ffffff',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    marginBottom: 30,
    color: '#333',
  },
  count: {
    fontSize: 48,
    fontWeight: 'bold',
    marginBottom: 30,
    color: '#007AFF',
  },
  buttonContainer: {
    flexDirection: 'row',
    marginBottom: 30,
  },
  button: {
    width: 60,
    height: 60,
    borderRadius: 30,
    backgroundColor: '#007AFF',
    justifyContent: 'center',
    alignItems: 'center',
    marginHorizontal: 10,
  },
  buttonText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#ffffff',
  },
  messageContainer: {
    width: '100%',
  },
  messageButton: {
    backgroundColor: '#34C759',
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 8,
    marginVertical: 5,
    alignItems: 'center',
  },
  messageButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
  // Calculator Styles
  display: {
    fontSize: 36,
    fontWeight: 'bold',
    textAlign: 'right',
    marginBottom: 20,
    paddingHorizontal: 20,
    color: '#333',
  },
  calculatorGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'center',
    marginBottom: 20,
  },
  calcButton: {
    width: 70,
    height: 70,
    backgroundColor: '#f0f0f0',
    justifyContent: 'center',
    alignItems: 'center',
    margin: 5,
    borderRadius: 35,
  },
  calcButtonText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
  },
  clearButton: {
    backgroundColor: '#FF3B30',
    paddingVertical: 12,
    paddingHorizontal: 30,
    borderRadius: 8,
    alignItems: 'center',
  },
  clearButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
})
