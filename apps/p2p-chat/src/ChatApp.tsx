import React, {useCallback} from 'react'
import {LogBox, View} from 'react-native'

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

const createSubtleBackground = (vibrantColor: string): string => {
  const hex = vibrantColor.replace('#', '')
  const r = parseInt(hex.substr(0, 2), 16)
  const g = parseInt(hex.substr(2, 2), 16)
  const b = parseInt(hex.substr(4, 2), 16)

  const lightR = Math.round(255 * 0.9 + r * 0.1)
  const lightG = Math.round(255 * 0.9 + g * 0.1)
  const lightB = Math.round(255 * 0.9 + b * 0.1)

  return `rgb(${lightR}, ${lightG}, ${lightB})`
}

LogBox.ignoreAllLogs()

const ChatApp: React.FC<ChatAppProps> = ({
  userId,
  userName,
  targetOptions: initialTargetOptions,
  potentialFriends: initialPotentialFriends,
  backgroundColor,
}) => {
  const {
    pendingRequests,
    targetOptions,
    potentialFriends,
    respondToFriendRequest,
    handleFriendMessage,
    sendFriendRequest,
  } = useFriendRequests({
    userName,
    initialTargetOptions,
    initialPotentialFriends,
    onSendMessage: (msg: MessageData) => sendMessage(msg),
  })

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
    onSendMessage: (message: MessageData, targetOrigin?: string) =>
      sendMessage(message, targetOrigin),
  })

  function handleIncomingMessage(data: MessageData) {
    console.log(`[${userName}] Processing message type: ${data.type}`)
    handleMessageIncoming(data)
    handleFriendMessage(data)
  }

  const isSelectedTargetFriend = targetOptions.includes(selectedTarget)

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
        isFriend={isSelectedTargetFriend}
        onInputChange={setInputText}
        onSendMessage={handleSendMessage}
      />
    </View>
  )
}

export default ChatApp
