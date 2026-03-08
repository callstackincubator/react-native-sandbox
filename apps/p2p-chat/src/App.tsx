import React, {useRef} from 'react'
import {Dimensions, SafeAreaView, StatusBar} from 'react-native'

import {ChatCarousel} from './components'
import {useChatInstances, useScrollColorInterpolation} from './hooks'
import {MessageHandler} from './services'
import {carouselStyles} from './styles'

const {width: screenWidth} = Dimensions.get('window')

const App = () => {
  const {
    chatInstances,
    currentIndex,
    setCurrentIndex,
    friendshipTrigger,
    friendshipManager,
    addChatInstance,
    removeChatInstance,
    triggerFriendshipUpdate,
  } = useChatInstances()

  const sandboxRefs = useRef<Record<string, any>>({})
  const chatInstancesRef = useRef(chatInstances)
  chatInstancesRef.current = chatInstances

  const messageHandler = useRef(
    new MessageHandler(
      () => chatInstancesRef.current,
      friendshipManager,
      sandboxRefs,
      triggerFriendshipUpdate
    )
  ).current

  const {currentBackgroundColor, onScroll} = useScrollColorInterpolation({
    chatInstances,
    scrollStep: screenWidth,
    onIndexChange: setCurrentIndex,
  })

  return (
    <SafeAreaView
      style={[
        carouselStyles.container,
        {backgroundColor: currentBackgroundColor},
      ]}>
      <StatusBar
        barStyle="light-content"
        backgroundColor={currentBackgroundColor}
      />

      <ChatCarousel
        chatInstances={chatInstances}
        currentIndex={currentIndex}
        friendshipTrigger={friendshipTrigger}
        friendshipManager={friendshipManager}
        sandboxRefs={sandboxRefs}
        messageHandler={messageHandler}
        onScroll={onScroll}
        onRemoveChatInstance={removeChatInstance}
        onAddChatInstance={addChatInstance}
      />
    </SafeAreaView>
  )
}

export default App
