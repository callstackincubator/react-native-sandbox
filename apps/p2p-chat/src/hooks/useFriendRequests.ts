import {useCallback, useState} from 'react'

import {
  FriendAction,
  FriendRequest,
  MessageData,
  PotentialFriend,
} from '../types'

interface UseFriendRequestsProps {
  userName: string
  initialTargetOptions: string[]
  initialPotentialFriends: PotentialFriend[]
  onSendMessage: (message: MessageData) => boolean
}

export const useFriendRequests = ({
  userName,
  initialTargetOptions,
  initialPotentialFriends,
  onSendMessage,
}: UseFriendRequestsProps) => {
  const [pendingRequests, setPendingRequests] = useState<FriendRequest[]>([])
  const [targetOptions, setTargetOptions] =
    useState<string[]>(initialTargetOptions)
  const [potentialFriends, setPotentialFriends] = useState<PotentialFriend[]>(
    initialPotentialFriends
  )

  const addFriend = useCallback((friendId: string) => {
    setTargetOptions(prev =>
      prev.includes(friendId) ? prev : [...prev, friendId]
    )
    setPotentialFriends(prev => prev.filter(pf => pf.id !== friendId))
  }, [])

  const sendFriendRequest = useCallback(
    (targetId: string) => {
      const success = onSendMessage({
        type: 'friend_request',
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

      const request = pendingRequests.find(r => r.id === requestId)

      const success = onSendMessage({
        type: 'friend_response',
        requestId,
        action,
        timestamp: Date.now(),
      })

      if (success) {
        setPendingRequests(prev => prev.filter(r => r.id !== requestId))

        if (action === 'accept' && request) {
          addFriend(request.fromId)
          console.log(`[${userName}] Now friends with ${request.from}`)
        }
      }
    },
    [userName, onSendMessage, pendingRequests, addFriend]
  )

  const handleFriendMessage = useCallback(
    (data: MessageData) => {
      switch (data.type) {
        case 'friend_request': {
          if (data.requestId && data.from) {
            console.log(
              `[${userName}] Received friend request from ${data.fromName ?? data.from}`
            )
            setPendingRequests(prev => {
              if (prev.some(r => r.id === data.requestId)) return prev
              return [
                ...prev,
                {
                  id: data.requestId!,
                  fromId: data.from!,
                  from: data.fromName ?? data.from!,
                  to: userName,
                  timestamp: data.timestamp,
                },
              ]
            })
          }
          break
        }

        case 'friend_response': {
          const friendId = data.friend
          if (friendId && data.action === 'accept') {
            console.log(
              `[${userName}] Friend request accepted by ${data.friendName ?? friendId}`
            )
            addFriend(friendId)
          } else if (data.action === 'reject') {
            console.log(
              `[${userName}] Friend request rejected by ${data.friendName ?? data.friend}`
            )
          }
          break
        }
      }
    },
    [userName, addFriend]
  )

  return {
    pendingRequests,
    targetOptions,
    potentialFriends,
    sendFriendRequest,
    respondToFriendRequest,
    handleFriendMessage,
  }
}
