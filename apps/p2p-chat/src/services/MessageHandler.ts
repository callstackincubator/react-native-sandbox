import {ChatMeta} from '../constants'
import {FriendshipManager} from './FriendshipManager'

export class MessageHandler {
  private scrollToChat?: (chatId: string) => void

  constructor(
    private chatInstances: ChatMeta[],
    private friendshipManager: FriendshipManager,
    private sandboxRefs: React.MutableRefObject<Record<string, any>>,
    private triggerFriendshipUpdate: () => void
  ) {}

  setScrollToChat = (scrollFunction: (chatId: string) => void) => {
    this.scrollToChat = scrollFunction
  }

  handleChatError = (chatId: string) => (error: any) => {
    console.log(`[${chatId}] Error:`, error)

    // Send error message to sandbox for display in chat history
    const errorMessage = {
      type: 'message_error',
      errorText: error.message || 'An error occurred',
      reason: error.name || 'unknown_error',
      timestamp: Date.now(),
    }

    this.sendToSandbox(chatId, errorMessage)
  }

  handleChatMessage = (chatId: string) => (data: any) => {
    console.log(`[${chatId}] Received message from sandbox:`, data)

    if (!data.type) {
      console.warn(`[Host] Message from ${chatId} missing type:`, data)
      return
    }

    switch (data.type) {
      case 'make_friend':
        this.handleMakeFriend(chatId, data)
        break
      case 'friend_response':
        this.handleFriendResponse(chatId, data)
        break
      case 'chat_message':
        this.handleForwardMessage(chatId, data)
        break
      default:
        console.log(`[Host] Unknown message type from ${chatId}:`, data.type)
    }
  }

  private handleMakeFriend(chatId: string, data: any) {
    const {target} = data
    if (!target) {
      console.warn(`[Host] make_friend message from ${chatId} missing target`)
      return
    }

    const targetInstance = this.chatInstances.find(inst => inst.id === target)
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

    // Automatically scroll to target chat to make it easier to accept the invite
    if (this.scrollToChat) {
      setTimeout(() => {
        this.scrollToChat!(target)
      }, 100) // Small delay for UX
    }

    setTimeout(() => {
      const hostMessage = {
        type: 'friend_request',
        from: chatId,
        fromName:
          this.chatInstances.find(inst => inst.id === chatId)?.userName ||
          chatId,
        requestId,
        timestamp: Date.now(),
      }

      this.sendToSandbox(target, hostMessage)
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

    if (action === 'accept') {
      // Notify the original requester
      const acceptMessage = {
        type: 'friend_accepted',
        friend: chatId,
        friendName:
          this.chatInstances.find(inst => inst.id === chatId)?.userName ||
          chatId,
        timestamp: Date.now(),
      }
      this.sendToSandbox(request.from, acceptMessage)

      // Notify both parties about established friendship
      const friendshipMessage = {
        type: 'friendship_established',
        friendName: '',
        timestamp: Date.now(),
      }

      this.sendToSandbox(request.from, {
        ...friendshipMessage,
        friendName:
          this.chatInstances.find(inst => inst.id === chatId)?.userName ||
          chatId,
      })

      this.sendToSandbox(chatId, {
        ...friendshipMessage,
        friendName:
          this.chatInstances.find(inst => inst.id === request.from)?.userName ||
          request.from,
      })
    }
  }

  private handleForwardMessage(senderId: string, data: any) {
    const {target, messageId, text, senderName, timestamp} = data

    if (!target || !messageId || !text || !senderName) {
      console.warn(
        `[Host] chat_message from ${senderId} missing required fields`
      )
      return
    }

    const forwardedMessage = {
      type: 'chat_message',
      messageId,
      text,
      senderId,
      senderName,
      timestamp,
    }

    // Message will be blocked at native level if not allowed
    this.sendToSandbox(target, forwardedMessage)
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
