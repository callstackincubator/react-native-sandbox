export interface FriendRequest {
  id: string
  fromId: string
  from: string
  to: string
  timestamp: number
}

export interface PotentialFriend {
  id: string
  name: string
}

export type FriendAction = 'accept' | 'reject'
