import React, {useCallback, useRef} from 'react'
import {
  NativeScrollEvent,
  NativeSyntheticEvent,
  SafeAreaView,
  StatusBar,
} from 'react-native'

import {ChatCarousel} from './components'
import {CHAT_WIDTH} from './constants'
import {useChatInstances} from './hooks'
import {MessageHandler} from './services'
import {carouselStyles} from './styles'

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

  const onScroll = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      const slideIndex = Math.round(
        event.nativeEvent.contentOffset.x / CHAT_WIDTH
      )
      setCurrentIndex(slideIndex)
    },
    [setCurrentIndex]
  )

  return (
    <SafeAreaView style={carouselStyles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#f8f9fa" />

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
