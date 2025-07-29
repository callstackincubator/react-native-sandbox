import {useCallback, useEffect} from 'react'

import {MessageData} from '../types'

// Global function declarations for sandbox environment
declare global {
  var setOnMessage: (callback: (data: any) => void) => void
  var postMessage: (message: any, targetOrigin?: string) => void
}

interface UseCommunicationProps {
  userName: string
  userId: string
  onMessage: (data: MessageData) => void
  onConnectionEstablished?: () => void
}

export const useCommunication = ({
  userName,
  userId,
  onMessage,
  onConnectionEstablished,
}: UseCommunicationProps) => {
  useEffect(() => {
    // Set up message listener for P2P communication
    if (global.setOnMessage) {
      console.log(
        `[${userName}] global.setOnMessage is available, setting up listener`
      )
      global.setOnMessage((data: any) => {
        console.log(`[${userName}] 🔥 MESSAGE RECEIVED:`, data)

        if (!data || !data.type) {
          console.warn(`[${userName}] Received message without type:`, data)
          return
        }

        console.log(`[${userName}] Processing message type: ${data.type}`)
        onMessage(data)
      })

      console.log(`[${userName}] ✅ Message listener setup complete`)
    } else {
      console.warn(`[${userName}] ❌ global.setOnMessage is not available!`)
      console.log(
        `[${userName}] Available global functions:`,
        Object.keys(global).filter(
          key => typeof (global as any)[key] === 'function'
        )
      )
    }

    // Send initial connection message if callback provided
    if (onConnectionEstablished) {
      onConnectionEstablished()
    }

    // Announce readiness
    console.log(
      `[${userName}] 📢 Sandbox initialization complete and ready to receive messages`
    )
  }, [userName, onMessage, onConnectionEstablished])

  const sendMessage = useCallback(
    (message: MessageData, targetOrigin?: string) => {
      if (global.postMessage) {
        try {
          global.postMessage(message, targetOrigin)
          return true
        } catch (error) {
          console.error(`[${userName}] Failed to send message:`, error)
          return false
        }
      }
      return false
    },
    [userName]
  )

  const sendConnectionMessage = useCallback(
    (targets: string[]) => {
      if (global.postMessage && targets.length > 0) {
        targets.forEach(targetId => {
          global.postMessage!(
            {
              type: 'connection_established',
              senderId: userId,
              senderName: userName,
              timestamp: Date.now(),
            },
            targetId
          )
        })
      }
    },
    [userId, userName]
  )

  return {
    sendMessage,
    sendConnectionMessage,
    isReady: !!global.postMessage,
  }
}
