import {useCallback, useState} from 'react'

import {Message, MessageData} from '../types'

interface UseMessagesProps {
  userId: string
  userName: string
  onSendMessage: (message: MessageData) => boolean
}

export const useMessages = ({
  userId,
  userName,
  onSendMessage,
}: UseMessagesProps) => {
  const [messages, setMessages] = useState<Message[]>([])
  const [inputText, setInputText] = useState('')

  const addMessage = useCallback((message: Message) => {
    setMessages(prev => [...prev, message])
  }, [])

  const sendChatMessage = useCallback(
    (target: string) => {
      if (!inputText.trim() || !target.trim()) return

      const messageId = `${userId}_${Date.now()}`
      const timestamp = Date.now()

      // Add to local messages
      const newMessage: Message = {
        id: messageId,
        text: inputText.trim(),
        sender: userName,
        timestamp,
        type: 'sent',
      }

      addMessage(newMessage)

      // Send P2P message to selected target sandbox via host
      const success = onSendMessage({
        type: 'chat_message',
        messageId,
        text: inputText.trim(),
        senderId: userId,
        senderName: userName,
        timestamp,
        target: target.trim(),
      })

      if (!success) {
        // Add a local error message
        const errorMessage: Message = {
          id: `error_${Date.now()}`,
          text: `Failed to send message: Communication error`,
          sender: 'System',
          timestamp: Date.now(),
          type: 'error',
          isError: true,
          errorReason: 'send_failed',
        }
        addMessage(errorMessage)
      }

      setInputText('')
    },
    [inputText, userId, userName, onSendMessage, addMessage]
  )

  const handleIncomingMessage = useCallback(
    (data: MessageData) => {
      switch (data.type) {
        case 'chat_message': {
          if (data.messageId && data.text && data.senderName) {
            const newMessage: Message = {
              id: data.messageId,
              text: data.text,
              sender: data.senderName,
              timestamp: data.timestamp,
              type: 'received',
            }
            addMessage(newMessage)
          }
          break
        }

        case 'message_error': {
          if (data.errorText) {
            const errorMessage: Message = {
              id: `error_${Date.now()}`,
              text: data.errorText,
              sender: 'System',
              timestamp: data.timestamp,
              type: 'error',
              isError: true,
              errorReason: data.reason,
            }
            addMessage(errorMessage)
          }
          break
        }
      }
    },
    [addMessage]
  )

  return {
    messages,
    inputText,
    setInputText,
    sendChatMessage,
    handleIncomingMessage,
    addMessage,
  }
}
