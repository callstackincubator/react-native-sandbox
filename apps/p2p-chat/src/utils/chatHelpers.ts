import {ChatMeta} from '../constants'
import {FriendshipManager} from '../services'

export const getChatHelpers = (
  chatInstances: ChatMeta[],
  friendshipManager: FriendshipManager
) => {
  const getTargetOptions = (chatId: string): string[] => {
    return friendshipManager.getFriends(chatId)
  }

  const getPotentialFriends = (chatId: string) => {
    return chatInstances
      .filter(chat => chat.id !== chatId)
      .filter(chat => !friendshipManager.areFriends(chatId, chat.id))
      .filter(
        chat => !friendshipManager.hasPendingRequestBetween(chatId, chat.id)
      )
      .map(chat => ({id: chat.id, name: chat.userName}))
  }

  const getFriends = (chatId: string) => {
    return chatInstances
      .filter(chat => chat.id !== chatId)
      .filter(chat => friendshipManager.areFriends(chatId, chat.id))
      .map(chat => ({id: chat.id, name: chat.userName}))
  }

  return {
    getTargetOptions,
    getPotentialFriends,
    getFriends,
  }
}

export const createChatInstance = (name: string, color: string): ChatMeta => ({
  id: name.toLowerCase(),
  userName: name,
  backgroundColor: color,
})
