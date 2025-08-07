import React, {useCallback, useState} from 'react'
import {LogBox, StatusBar, View} from 'react-native'

import {
  FriendRequestsList,
  MessageInput,
  MessagesList,
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

// Utility function to create subtle background from vibrant color
const createSubtleBackground = (vibrantColor: string): string => {
  // Convert hex to RGB
  const hex = vibrantColor.replace('#', '')
  const r = parseInt(hex.substr(0, 2), 16)
  const g = parseInt(hex.substr(2, 2), 16)
  const b = parseInt(hex.substr(4, 2), 16)

  // Create a very light version (90% white + 10% color)
  const lightR = Math.round(255 * 0.9 + r * 0.1)
  const lightG = Math.round(255 * 0.9 + g * 0.1)
  const lightB = Math.round(255 * 0.9 + b * 0.1)

  return `rgb(${lightR}, ${lightG}, ${lightB})`
}

LogBox.ignoreAllLogs()

const ChatApp: React.FC<ChatAppProps> = ({
  userId,
  userName,
  targetOptions,
  potentialFriends,
  pendingRequests,
  backgroundColor,
}) => {
  const [, setIsConnected] = useState(false)

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

  const {respondToFriendRequest, handleFriendMessage, sendFriendRequest} =
    useFriendRequests({
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

  const subtleBackground = createSubtleBackground(backgroundColor)

  return (
    <View style={[commonStyles.container, {backgroundColor: subtleBackground}]}>
      <StatusBar backgroundColor={backgroundColor} barStyle="light-content" />

      <FriendRequestsList
        pendingRequests={pendingRequests}
        onRespondToRequest={respondToFriendRequest}
      />

      <TargetSelector
        targetOptions={targetOptions}
        potentialFriends={potentialFriends}
        selectedTarget={selectedTarget}
        onTargetSelect={handleTargetSelect}
        onSendFriendRequest={handleSendFriendRequest}
      />

      <MessagesList messages={messages} selectedTarget={selectedTarget} />

      <MessageInput
        inputText={inputText}
        selectedTarget={selectedTarget}
        onInputChange={setInputText}
        onSendMessage={handleSendMessage}
      />
    </View>
  )
}

export default ChatApp
