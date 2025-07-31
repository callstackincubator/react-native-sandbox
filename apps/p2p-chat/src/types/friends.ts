export interface FriendRequest {
  id: string
  from: string
  to: string
  timestamp: number
  status?: 'pending' | 'accepted' | 'rejected'
}

export interface PotentialFriend {
  id: string
  name: string
}

export type FriendAction = 'accept' | 'reject'

export interface FriendNotification {
  id: string
  text: string
  timestamp: number
}
