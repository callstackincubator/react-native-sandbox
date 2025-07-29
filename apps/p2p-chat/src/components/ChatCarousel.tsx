import React, {useRef} from 'react'
import {
  NativeScrollEvent,
  NativeSyntheticEvent,
  ScrollView,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'
import SandboxReactNativeView from '@callstack/react-native-sandbox'

import {ChatInstance, MAX_CHAT_INSTANCES} from '../constants'
import {FriendshipManager, MessageHandler} from '../services'
import {carouselStyles} from '../styles'
import {getChatHelpers} from '../utils/chatHelpers'

interface ChatCarouselProps {
  chatInstances: ChatInstance[]
  currentIndex: number
  friendshipTrigger: number
  friendshipManager: FriendshipManager
  sandboxRefs: React.MutableRefObject<Record<string, any>>
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
  const {getTargetOptions, getPotentialFriends, getPendingRequests} =
    getChatHelpers(chatInstances, friendshipManager)

  const canAddMore = chatInstances.length < MAX_CHAT_INSTANCES

  return (
    <>
      <View style={carouselStyles.carouselContainer}>
        <ScrollView
          ref={scrollViewRef}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          onScroll={onScroll}
          scrollEventThrottle={16}
          style={carouselStyles.carousel}>
          {chatInstances.map((chat, index) => (
            <View key={chat.id} style={carouselStyles.chatSlide}>
              <View style={carouselStyles.chatHeader}>
                <TouchableOpacity
                  style={carouselStyles.deleteButton}
                  onPress={() => onRemoveChatInstance(chat.id)}
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

                <View style={carouselStyles.chatHeaderContent}>
                  <Text style={carouselStyles.chatTitle}>
                    {chat.userName} ({chat.id})
                  </Text>
                  <Text style={carouselStyles.chatSubtitle}>
                    Friends: {getTargetOptions(chat.id).join(', ') || 'None'}
                  </Text>
                  <TouchableOpacity
                    style={carouselStyles.testButton}
                    onPress={() =>
                      messageHandler.testHostToSandboxCommunication(chat.id)
                    }>
                    <Text style={carouselStyles.testButtonText}>Test</Text>
                  </TouchableOpacity>
                </View>
              </View>

              <View style={carouselStyles.chatContainer}>
                <SandboxReactNativeView
                  ref={ref => {
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
                  }}
                  id={chat.id}
                  moduleName="ChatApp"
                  initialProperties={{
                    userId: chat.id,
                    userName: chat.userName,
                    targetOptions: getTargetOptions(chat.id),
                    potentialFriends: getPotentialFriends(chat.id),
                    pendingRequests: getPendingRequests(chat.id),
                    backgroundColor: chat.backgroundColor,
                    friendshipTrigger: friendshipTrigger,
                  }}
                  onError={messageHandler.handleChatError(chat.userName)}
                  onMessage={messageHandler.handleChatMessage(chat.id)}
                  style={carouselStyles.sandbox}
                />
              </View>
            </View>
          ))}

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
          Swipe between instances • Add friends • Send messages{'\n'}
          Each instance runs in an isolated React Native sandbox
        </Text>
      </View>
    </>
  )
}
