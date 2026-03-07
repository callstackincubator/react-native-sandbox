import React from 'react'
import {Pressable, StyleSheet, Text, View} from 'react-native'

import {
  buttonStyles,
  colors,
  commonStyles,
  spacing,
  typography,
} from '../styles/common'
import {FriendAction, FriendRequest} from '../types/friends'

interface FriendRequestsListProps {
  pendingRequests: FriendRequest[]
  onRespondToRequest: (requestId: string, action: FriendAction) => void
}

export const FriendRequestsList: React.FC<FriendRequestsListProps> = ({
  pendingRequests,
  onRespondToRequest,
}) => {
  if (pendingRequests.length === 0) {
    return null
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Friend Requests</Text>
      {pendingRequests.map(request => (
        <View key={request.id} style={styles.friendRequest}>
          <Text style={styles.friendRequestText}>
            {request.from} wants to be friends
          </Text>
          <View style={styles.buttonContainer}>
            <Pressable
              style={[
                buttonStyles.base,
                buttonStyles.success,
                styles.actionButton,
              ]}
              onPress={() => onRespondToRequest(request.id, 'accept')}>
              <Text style={[buttonStyles.text, styles.buttonText]}>Accept</Text>
            </Pressable>
            <Pressable
              style={[
                buttonStyles.base,
                buttonStyles.error,
                styles.actionButton,
              ]}
              onPress={() => onRespondToRequest(request.id, 'reject')}>
              <Text style={[buttonStyles.text, styles.buttonText]}>Reject</Text>
            </Pressable>
          </View>
        </View>
      ))}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    padding: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    backgroundColor: 'rgba(255,255,255,0.95)',
  },
  title: {
    fontSize: typography.sizes.lg,
    fontWeight: typography.weights.semibold,
    color: colors.text.primary,
    marginBottom: spacing.sm,
  },
  friendRequest: {
    ...commonStyles.row,
    justifyContent: 'space-between',
    backgroundColor: '#f0f0f0',
    padding: spacing.sm + 2,
    ...commonStyles.rounded,
    marginBottom: spacing.sm,
    ...commonStyles.border,
  },
  friendRequestText: {
    flex: 1,
    fontSize: typography.sizes.md + 1,
    color: colors.text.primary,
    marginRight: spacing.sm + 2,
  },
  buttonContainer: {
    flexDirection: 'row',
  },
  actionButton: {
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    marginLeft: spacing.sm,
  },
  buttonText: {
    fontSize: typography.sizes.md,
  },
})
