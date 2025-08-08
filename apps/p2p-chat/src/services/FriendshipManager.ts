import {FriendRequest} from '../types'

export class FriendshipManager {
  private friendships = new Set<string>() // "alice-bob" format (sorted)
  private pendingRequests = new Map<string, FriendRequest>()
  private requestCounter = 0

  private createFriendshipKey(user1: string, user2: string): string {
    return [user1, user2].sort().join('-')
  }

  sendFriendRequest(from: string, to: string): string {
    const requestId = `req_${++this.requestCounter}_${Date.now()}`
    const request: FriendRequest = {
      id: requestId,
      from,
      to,
      timestamp: Date.now(),
      status: 'pending',
    }

    this.pendingRequests.set(requestId, request)
    console.log(
      `[FriendshipManager] Friend request sent: ${from} → ${to} (${requestId})`
    )
    return requestId
  }

  respondToRequest(
    requestId: string,
    action: 'accept' | 'reject'
  ): FriendRequest | null {
    const request = this.pendingRequests.get(requestId)
    if (!request) {
      console.warn(`[FriendshipManager] Request ${requestId} not found`)
      return null
    }

    request.status = action === 'accept' ? 'accepted' : 'rejected'

    if (action === 'accept') {
      const friendshipKey = this.createFriendshipKey(request.from, request.to)
      this.friendships.add(friendshipKey)
      console.log(
        `[FriendshipManager] Friendship established: ${request.from} ↔ ${request.to}`
      )
    }

    this.pendingRequests.delete(requestId)
    return request
  }

  getFriends(userId: string): string[] {
    const friends: string[] = []
    for (const friendship of this.friendships) {
      const [user1, user2] = friendship.split('-')
      if (user1 === userId) friends.push(user2)
      if (user2 === userId) friends.push(user1)
    }
    return friends
  }

  getPendingRequestsFor(userId: string): FriendRequest[] {
    return Array.from(this.pendingRequests.values()).filter(
      req => req.to === userId && req.status === 'pending'
    )
  }

  hasPendingRequestBetween(user1: string, user2: string): boolean {
    return Array.from(this.pendingRequests.values()).some(
      req =>
        (req.from === user1 && req.to === user2) ||
        (req.from === user2 && req.to === user1)
    )
  }

  areFriends(user1: string, user2: string): boolean {
    return this.friendships.has(this.createFriendshipKey(user1, user2))
  }
}
