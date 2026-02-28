import {ChatMeta} from '../constants'
import {FriendshipManager} from './FriendshipManager'

export class MessageHandler {
  private scrollToChat?: (chatId: string) => void

  constructor(
    private getChatInstances: () => ChatMeta[],
    private friendshipManager: FriendshipManager,
    private sandboxRefs: React.MutableRefObject<Record<string, any>>,
    private triggerFriendshipUpdate: () => void
  ) {}

  setScrollToChat = (scrollFunction: (chatId: string) => void) => {
    this.scrollToChat = scrollFunction
  }

  handleChatError = (chatId: string) => (error: any) => {
    console.log(`[${chatId}] Error:`, error)

    const errorMessage = {
      type: 'message_error',
      errorText: error.message || 'An error occurred',
      reason: error.name || 'unknown_error',
      timestamp: Date.now(),
    }

    this.sendToSandbox(chatId, errorMessage)
  }

  handleChatMessage = (chatId: string) => (rawData: any) => {
    console.log(`[${chatId}] Received message from sandbox:`, rawData)

    const data = typeof rawData === 'string' ? JSON.parse(rawData) : rawData

    if (!data.type) {
      console.warn(`[Host] Message from ${chatId} missing type:`, data)
      return
    }

    switch (data.type) {
      case 'friend_request':
        this.handleFriendRequest(chatId, data)
        break
      case 'friend_response':
        this.handleFriendResponse(chatId, data)
        break
      default:
        console.log(`[Host] Unknown message type from ${chatId}:`, data.type)
    }
  }

  private handleFriendRequest(chatId: string, data: any) {
    const {target} = data
    if (!target) {
      console.warn(`[Host] friend_request from ${chatId} missing target`)
      return
    }

    const targetInstance = this.getChatInstances().find(
      inst => inst.id === target
    )
    if (!targetInstance) {
      console.warn(
        `[Host] Target ${target} not found for friend request from ${chatId}`
      )
      return
    }

    if (this.friendshipManager.areFriends(chatId, target)) {
      console.log(`[Host] ${chatId} and ${target} are already friends`)
      return
    }

    if (this.friendshipManager.hasPendingRequestBetween(chatId, target)) {
      console.log(
        `[Host] Pending friend request already exists between ${chatId} and ${target}`
      )
      return
    }

    const requestId = this.friendshipManager.sendFriendRequest(chatId, target)

    if (this.scrollToChat) {
      setTimeout(() => {
        this.scrollToChat!(target)
      }, 100)
    }

    setTimeout(() => {
      this.sendToSandbox(target, {
        type: 'friend_request',
        from: chatId,
        fromName:
          this.getChatInstances().find(inst => inst.id === chatId)?.userName ||
          chatId,
        requestId,
        timestamp: Date.now(),
      })
    }, 500)
  }

  private handleFriendResponse(chatId: string, data: any) {
    const {requestId, action} = data
    if (!requestId || !action) {
      console.warn(
        `[Host] friend_response from ${chatId} missing requestId or action`
      )
      return
    }

    const request = this.friendshipManager.respondToRequest(requestId, action)
    if (!request) return

    this.triggerFriendshipUpdate()

    const instances = this.getChatInstances()
    this.sendToSandbox(request.from, {
      type: 'friend_response',
      action,
      friend: chatId,
      friendName:
        instances.find(inst => inst.id === chatId)?.userName || chatId,
      requestId,
      timestamp: Date.now(),
    })
  }

  private sendToSandbox(targetId: string, message: any) {
    const targetRef = this.sandboxRefs.current[targetId]
    if (targetRef) {
      try {
        targetRef.postMessage(message)
        console.log(`[Host] Message sent to ${targetId}:`, message.type)
      } catch (error) {
        console.error(`[Host] Error sending message to ${targetId}:`, error)
      }
    } else {
      console.error(`[Host] Target ref for ${targetId} not found`)
    }
  }
}
