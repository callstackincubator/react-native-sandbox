import {useCallback, useRef, useState} from 'react'

import {ChatMeta, MAX_CHAT_INSTANCES, USER_THEMES} from '../constants'
import {FriendshipManager} from '../services'
import {createChatInstance} from '../utils/chatHelpers'

export const useChatInstances = () => {
  const [chatInstances, setChatInstances] = useState<ChatMeta[]>([
    createChatInstance(USER_THEMES[0].name, USER_THEMES[0].color),
    createChatInstance(USER_THEMES[1].name, USER_THEMES[1].color),
  ])
  const [currentIndex, setCurrentIndex] = useState(0)
  const [friendshipTrigger, setFriendshipTrigger] = useState(0)
  const friendshipManager = useRef(new FriendshipManager()).current

  const addChatInstance = useCallback(() => {
    if (chatInstances.length >= MAX_CHAT_INSTANCES) {
      console.log('Maximum number of chat instances reached')
      return
    }

    const usedNames = new Set(chatInstances.map(chat => chat.userName))
    const availableUser = USER_THEMES.find(user => !usedNames.has(user.name))

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
