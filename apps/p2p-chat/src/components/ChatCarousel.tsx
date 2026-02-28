import SandboxReactNativeView from '@callstack/react-native-sandbox'
import React, {useCallback, useEffect, useMemo, useRef} from 'react'
import {
  Alert,
  Dimensions,
  NativeScrollEvent,
  NativeSyntheticEvent,
  ScrollView,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'

import {ChatMeta, MAX_CHAT_INSTANCES} from '../constants'
import {FriendshipManager, MessageHandler} from '../services'
import {carouselStyles} from '../styles'
import {getChatHelpers} from '../utils/chatHelpers'

interface ChatInstanceViewProps {
  chat: ChatMeta
  index: number
  currentIndex: number
  friendshipTrigger: number
  friendshipManager: FriendshipManager
  messageHandler: MessageHandler
  sandboxRefs: React.RefObject<Record<string, any>>
  chatInstances: ChatMeta[]
  onRemoveChatInstance: (chatId: string) => void
}

const ChatInstanceView: React.FC<ChatInstanceViewProps> = React.memo(
  ({
    chat,
    index,
    currentIndex,
    friendshipTrigger,
    friendshipManager,
    messageHandler,
    sandboxRefs,
    chatInstances,
    onRemoveChatInstance,
  }) => {
    const isVisible = index === currentIndex
    const {getTargetOptions, getPotentialFriends, getFriends} = getChatHelpers(
      chatInstances,
      friendshipManager
    )

    const allowedOrigins = getFriends(chat.id).map(friend => friend.id)

    const initialProperties = useMemo(
      () => ({
        userId: chat.id,
        userName: chat.userName,
        targetOptions: getTargetOptions(chat.id),
        potentialFriends: getPotentialFriends(chat.id),
        backgroundColor: chat.backgroundColor,
      }),
      // Only recompute when the chat identity changes, NOT on friendship updates.
      // Friendship updates are delivered via postMessage to avoid full sandbox reload.
      // eslint-disable-next-line react-hooks/exhaustive-deps
      [chat.id, chat.userName, chat.backgroundColor]
    )

    const onError = useMemo(
      () => messageHandler.handleChatError(chat.userName),
      [messageHandler, chat.userName]
    )

    const onMessage = useMemo(
      () => messageHandler.handleChatMessage(chat.id),
      [messageHandler, chat.id]
    )

    const refCallback = useCallback(
      (ref: any) => {
        if (ref) {
          sandboxRefs.current[chat.id] = ref
          console.log(
            `[Host] Registered sandbox ref for ${chat.id}. Active refs:`,
            Object.keys(sandboxRefs.current)
          )
        } else {
          console.log(`[Host] Removing sandbox ref for ${chat.id}`)
          delete sandboxRefs.current[chat.id]
        }
      },
      [sandboxRefs, chat.id]
    )

    const handleRemove = useCallback(() => {
      Alert.alert('Remove Chat', `Remove ${chat.userName} from the chat?`, [
        {text: 'Cancel', style: 'cancel'},
        {
          text: 'Remove',
          style: 'destructive',
          onPress: () => onRemoveChatInstance(chat.id),
        },
      ])
    }, [onRemoveChatInstance, chat.id, chat.userName])

    return (
      <View key={chat.id} style={carouselStyles.chatSlide}>
        <View style={carouselStyles.chatContent}>
          <View style={carouselStyles.chatHeader}>
            <View style={carouselStyles.chatHeaderContent}>
              <Text style={carouselStyles.chatTitle}>{chat.id}</Text>
            </View>

            {isVisible && (
              <TouchableOpacity
                style={carouselStyles.deleteButton}
                onPress={handleRemove}
                disabled={chatInstances.length <= 1}>
                <Text
                  style={[
                    carouselStyles.deleteButtonText,
                    chatInstances.length <= 1 &&
                      carouselStyles.deleteButtonDisabled,
                  ]}>
                  ×
                </Text>
              </TouchableOpacity>
            )}
          </View>

          <View style={carouselStyles.chatContainer}>
            <SandboxReactNativeView
              ref={refCallback}
              origin={chat.id}
              componentName="ChatApp"
              initialProperties={initialProperties}
              onError={onError}
              onMessage={onMessage}
              allowedOrigins={allowedOrigins}
              style={carouselStyles.sandbox}
            />
          </View>
        </View>
      </View>
    )
  }
)
ChatInstanceView.displayName = 'ChatInstanceView'

interface AddChatViewProps {
  chatInstances: ChatMeta[]
  onAddChatInstance: () => void
}

const AddChatView: React.FC<AddChatViewProps> = ({
  chatInstances,
  onAddChatInstance,
}) => {
  const canAddMore = chatInstances.length < MAX_CHAT_INSTANCES

  return (
    <View style={carouselStyles.chatSlide}>
      <TouchableOpacity
        style={carouselStyles.addChatCard}
        onPress={onAddChatInstance}
        disabled={!canAddMore}>
        <View style={carouselStyles.addChatContent}>
          <Text
            style={[
              carouselStyles.addChatIcon,
              !canAddMore && carouselStyles.addChatIconDisabled,
            ]}>
            +
          </Text>
          <Text
            style={[
              carouselStyles.addChatText,
              !canAddMore && carouselStyles.addChatTextDisabled,
            ]}>
            Add Chat
          </Text>
          <Text style={carouselStyles.addChatLimitText}>
            {chatInstances.length} / {MAX_CHAT_INSTANCES}
          </Text>
        </View>
      </TouchableOpacity>
    </View>
  )
}

interface ChatCarouselProps {
  chatInstances: ChatMeta[]
  currentIndex: number
  friendshipTrigger: number
  friendshipManager: FriendshipManager
  sandboxRefs: React.RefObject<Record<string, any>>
  messageHandler: MessageHandler
  onScroll: (event: NativeSyntheticEvent<NativeScrollEvent>) => void
  onRemoveChatInstance: (chatId: string) => void
  onAddChatInstance: () => void
}

export const ChatCarousel: React.FC<ChatCarouselProps> = ({
  chatInstances,
  currentIndex,
  friendshipTrigger,
  friendshipManager,
  sandboxRefs,
  messageHandler,
  onScroll,
  onRemoveChatInstance,
  onAddChatInstance,
}) => {
  const scrollViewRef = useRef<ScrollView>(null)

  const scrollToChat = useCallback(
    (targetChatId: string) => {
      const targetIndex = chatInstances.findIndex(
        chat => chat.id === targetChatId
      )
      if (targetIndex !== -1 && scrollViewRef.current) {
        const {width: screenWidth} = Dimensions.get('window')
        const scrollX = targetIndex * screenWidth

        scrollViewRef.current.scrollTo({
          x: scrollX,
          y: 0,
          animated: true,
        })
      }
    },
    [chatInstances]
  )

  useEffect(() => {
    if (
      messageHandler &&
      typeof messageHandler.setScrollToChat === 'function'
    ) {
      messageHandler.setScrollToChat(scrollToChat)
    }
  }, [messageHandler, chatInstances, scrollToChat])

  return (
    <>
      <View style={carouselStyles.carouselContainer}>
        <ScrollView
          ref={scrollViewRef}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          onScroll={onScroll}
          scrollEventThrottle={8}
          decelerationRate="fast"
          bounces={false}
          style={carouselStyles.carousel}>
          {chatInstances.map((chat, idx) => (
            <ChatInstanceView
              key={chat.id}
              chat={chat}
              index={idx}
              currentIndex={currentIndex}
              friendshipTrigger={friendshipTrigger}
              friendshipManager={friendshipManager}
              messageHandler={messageHandler}
              sandboxRefs={sandboxRefs}
              chatInstances={chatInstances}
              onRemoveChatInstance={onRemoveChatInstance}
            />
          ))}

          <AddChatView
            chatInstances={chatInstances}
            onAddChatInstance={onAddChatInstance}
          />
        </ScrollView>
      </View>

      <View style={carouselStyles.pageIndicators}>
        {[...chatInstances, {id: 'add-button'}].map((_, index) => (
          <View
            key={index}
            style={[
              carouselStyles.pageIndicator,
              index === currentIndex && carouselStyles.activePageIndicator,
            ]}
          />
        ))}
      </View>

      <View style={carouselStyles.info}>
        <Text style={carouselStyles.infoText}>
          💬 Multi-Instance P2P Chat Demo{'\n'}
          Each chat runs in an isolated React Native sandbox
        </Text>
      </View>
    </>
  )
}
