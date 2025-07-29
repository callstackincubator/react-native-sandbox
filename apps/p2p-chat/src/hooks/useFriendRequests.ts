import {useCallback, useState} from 'react'

import {FriendAction, MessageData} from '../types'

interface UseFriendRequestsProps {
  userName: string
  onSendMessage: (message: MessageData) => boolean
}

export const useFriendRequests = ({
  userName,
  onSendMessage,
}: UseFriendRequestsProps) => {
  const [friendNotifications, setFriendNotifications] = useState<string[]>([])

  const clearNotification = useCallback((index: number) => {
    setFriendNotifications(prev => prev.filter((_, i) => i !== index))
  }, [])

  const addNotification = useCallback((notification: string) => {
    setFriendNotifications(prev => [...prev, notification])
  }, [])

  const sendFriendRequest = useCallback(
    (targetId: string) => {
      const success = onSendMessage({
        type: 'make_friend',
        target: targetId,
        timestamp: Date.now(),
      })

      if (success) {
        console.log(
          `[${userName}] Friend request sent to host for routing to ${targetId}`
        )
      }
    },
    [userName, onSendMessage]
  )

  const respondToFriendRequest = useCallback(
    (requestId: string, action: FriendAction) => {
      console.log(
        `[${userName}] Responding to friend request ${requestId}: ${action}`
      )

      const success = onSendMessage({
        type: 'friend_response',
        requestId,
        action,
        timestamp: Date.now(),
      })

      if (success) {
        console.log(`[${userName}] Friend response sent to host`)
      }
    },
    [userName, onSendMessage]
  )

  const handleFriendMessage = useCallback(
    (data: MessageData) => {
      switch (data.type) {
        case 'friend_request': {
          if (data.fromName) {
            console.log(
              `[${userName}] 🚨 PROCESSING FRIEND REQUEST from ${data.fromName} (${data.from})`
            )
            addNotification(`Friend request from ${data.fromName}`)
            console.log(`[${userName}] Friend request notification added`)
          }
          break
        }

        case 'friend_accepted': {
          if (data.friendName) {
            console.log(
              `[${userName}] Friend request accepted by ${data.friendName}`
            )
            addNotification(`${data.friendName} accepted your friend request!`)
          }
          break
        }

        case 'friendship_established': {
          if (data.friendName) {
            console.log(
              `[${userName}] Friendship established with ${data.friendName}`
            )
            addNotification(`You are now friends with ${data.friendName}!`)
          }
          break
        }

        case 'test_message': {
          if (data.message) {
            console.log(
              `[${userName}] 🧪 RECEIVED TEST MESSAGE from host: ${data.message}`
            )
            addNotification(`Test: ${data.message}`)
          }
          break
        }
      }
    },
    [userName, addNotification]
  )

  return {
    friendNotifications,
    clearNotification,
    addNotification,
    sendFriendRequest,
    respondToFriendRequest,
    handleFriendMessage,
  }
}
