import {ChatInstance} from '../constants'
import {FriendshipManager} from '../services'

export const getChatHelpers = (
  chatInstances: ChatInstance[],
  friendshipManager: FriendshipManager
) => {
  const getTargetOptions = (chatId: string): string[] => {
    return friendshipManager.getFriends(chatId)
  }

  const getPotentialFriends = (chatId: string) => {
    return chatInstances
      .filter(chat => chat.id !== chatId) // Exclude self
      .filter(chat => !friendshipManager.areFriends(chatId, chat.id)) // Exclude existing friends
      .filter(
        chat => !friendshipManager.hasPendingRequestBetween(chatId, chat.id)
      ) // Exclude pending requests
      .map(chat => ({id: chat.id, name: chat.userName}))
  }

  const getPendingRequests = (chatId: string) => {
    return friendshipManager.getPendingRequestsFor(chatId)
  }

  return {
    getTargetOptions,
    getPotentialFriends,
    getPendingRequests,
  }
}

export const createChatInstance = (
  name: string,
  color: string
): ChatInstance => ({
  id: name.toLowerCase(),
  userName: name,
  backgroundColor: color,
})
