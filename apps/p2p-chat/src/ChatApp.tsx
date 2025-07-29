import React, {useCallback, useState} from 'react'
import {LogBox, View} from 'react-native'

import {
  ChatHeader,
  DebugInfo,
  FriendRequestsList,
  MessageInput,
  MessagesList,
  NotificationsList,
  TargetSelector,
} from './components'
import {
  useCommunication,
  useFriendRequests,
  useMessages,
  useTargetSelection,
} from './hooks'
import {commonStyles} from './styles'
import {ChatAppProps, MessageData} from './types'

LogBox.ignoreAllLogs()

const ChatApp: React.FC<ChatAppProps> = ({
  userId,
  userName,
  targetOptions,
  potentialFriends,
  pendingRequests,
  backgroundColor,
}) => {
  const [isConnected, setIsConnected] = useState(false)

  const {sendMessage, sendConnectionMessage} = useCommunication({
    userName,
    userId,
    onMessage: handleIncomingMessage,
    onConnectionEstablished: () => {
      const allTargets = [
        ...targetOptions,
        ...potentialFriends.map(pf => pf.id),
      ]
      sendConnectionMessage(allTargets)
    },
  })

  const {selectedTarget, setSelectedTarget} = useTargetSelection({
    targetOptions,
    potentialFriends,
  })

  const {
    messages,
    inputText,
    setInputText,
    sendChatMessage,
    handleIncomingMessage: handleMessageIncoming,
  } = useMessages({
    userId,
    userName,
    onSendMessage: (message: MessageData) => {
      const success = sendMessage(message)
      if (success) {
        setIsConnected(true)
      }
      return success
    },
  })

  const {
    friendNotifications,
    clearNotification,
    respondToFriendRequest,
    handleFriendMessage,
    sendFriendRequest,
  } = useFriendRequests({
    userName,
    onSendMessage: sendMessage,
  })

  function handleIncomingMessage(data: MessageData) {
    console.log(`[${userName}] Processing message type: ${data.type}`)

    handleMessageIncoming(data)
    handleFriendMessage(data)
    if (
      data.type === 'chat_message' ||
      data.type === 'connection_established'
    ) {
      setIsConnected(true)
    }
  }

  const handleSendMessage = useCallback(() => {
    sendChatMessage(selectedTarget)
  }, [sendChatMessage, selectedTarget])

  const handleTargetSelect = useCallback(
    (target: string) => {
      setSelectedTarget(target)
    },
    [setSelectedTarget]
  )

  const handleSendFriendRequest = useCallback(
    (targetId: string) => {
      sendFriendRequest(targetId)
    },
    [sendFriendRequest]
  )

  return (
    <View style={[commonStyles.container, {backgroundColor}]}>
      <ChatHeader userName={userName} isConnected={isConnected} />

      <NotificationsList
        notifications={friendNotifications}
        onClearNotification={clearNotification}
      />

      <FriendRequestsList
        pendingRequests={pendingRequests}
        onRespondToRequest={respondToFriendRequest}
      />

      <TargetSelector
        targetOptions={targetOptions}
        potentialFriends={potentialFriends}
        selectedTarget={selectedTarget}
        onTargetSelect={handleTargetSelect}
        onTargetChange={setSelectedTarget}
        onSendFriendRequest={handleSendFriendRequest}
      />

      <MessagesList messages={messages} selectedTarget={selectedTarget} />

      <MessageInput
        inputText={inputText}
        selectedTarget={selectedTarget}
        onInputChange={setInputText}
        onSendMessage={handleSendMessage}
      />

      <DebugInfo
        userId={userId}
        targetOptions={targetOptions}
        potentialFriendsCount={potentialFriends.length}
        messageCount={messages.length}
      />
    </View>
  )
}

export default ChatApp
