import {useCallback, useRef, useState} from 'react'

import {ChatInstance, MAX_CHAT_INSTANCES, PRESET_USERS} from '../constants'
import {FriendshipManager} from '../services'
import {createChatInstance} from '../utils/chatHelpers'

export const useChatInstances = () => {
  const [chatInstances, setChatInstances] = useState<ChatInstance[]>([
    {id: 'alice', userName: 'Alice', backgroundColor: '#e3f2fd'},
    {id: 'bob', userName: 'Bob', backgroundColor: '#f3e5f5'},
  ])
  const [currentIndex, setCurrentIndex] = useState(0)
  const [friendshipTrigger, setFriendshipTrigger] = useState(0)
  const friendshipManager = useRef(new FriendshipManager()).current

  const addChatInstance = useCallback(() => {
    if (chatInstances.length >= MAX_CHAT_INSTANCES) {
      console.log('Maximum number of chat instances reached')
      return
    }

    // Find the next available preset user
    const usedNames = new Set(chatInstances.map(chat => chat.userName))
    const availableUser = PRESET_USERS.find(user => !usedNames.has(user.name))

    if (!availableUser) {
      console.log('No more preset users available')
      return
    }

    const newInstance = createChatInstance(
      availableUser.name,
      availableUser.color
    )
    setChatInstances(prev => [...prev, newInstance])

    console.log(`[Host] Added new chat instance: ${newInstance.userName}`)
  }, [chatInstances])

  const removeChatInstance = useCallback(
    (chatId: string) => {
      if (chatInstances.length <= 1) {
        console.log('Cannot remove the last chat instance')
        return
      }

      setChatInstances(prev => prev.filter(chat => chat.id !== chatId))
      console.log(`[Host] Removed chat instance: ${chatId}`)

      // Trigger friendship updates since instances changed
      setFriendshipTrigger(prev => prev + 1)
    },
    [chatInstances.length]
  )

  const triggerFriendshipUpdate = useCallback(() => {
    setFriendshipTrigger(prev => prev + 1)
  }, [])

  return {
    chatInstances,
    currentIndex,
    setCurrentIndex,
    friendshipTrigger,
    friendshipManager,
    addChatInstance,
    removeChatInstance,
    triggerFriendshipUpdate,
  }
}
