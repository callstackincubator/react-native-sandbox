export interface Message {
  id: string
  text: string
  sender: string
  timestamp: number
  type: 'sent' | 'received' | 'error'
  isError?: boolean
  errorReason?: string
}

export interface ChatAppProps {
  userId: string
  userName: string
  targetOptions: string[] // Array of friend IDs who can receive messages
  potentialFriends: {id: string; name: string}[] // Users who can be added as friends
  pendingRequests: {id: string; from: string; to: string; timestamp: number}[] // Incoming friend requests
  backgroundColor: string
  friendshipTrigger?: number // Trigger prop to force re-renders
}

export interface MessageData {
  type: string
  messageId?: string
  text?: string
  senderId?: string
  senderName?: string
  timestamp: number
  target?: string
  from?: string
  fromName?: string
  requestId?: string
  action?: string
  friend?: string
  friendName?: string
  reason?: string
  errorText?: string
  message?: string
}

export interface GlobalCommunication {
  setOnMessage: (callback: (data: any) => void) => void
  postMessage: (message: any, targetOrigin?: string) => void
}
