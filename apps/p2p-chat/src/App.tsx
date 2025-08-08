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

  const messageHandler = new MessageHandler(
    chatInstances,
    friendshipManager,
    sandboxRefs,
    triggerFriendshipUpdate
  )

  // Use the scroll color interpolation hook
  const {currentBackgroundColor, onScroll} = useScrollColorInterpolation({
    chatInstances,
    scrollStep: screenWidth, // Now each slide takes full screen width
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
        translucent
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
