import React from 'react'
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native'

import {colors, commonStyles, spacing, typography} from '../styles'
import {PotentialFriend} from '../types'

interface TargetSelectorProps {
  targetOptions: string[]
  potentialFriends: PotentialFriend[]
  selectedTarget: string
  onTargetSelect: (target: string) => void
  onSendFriendRequest: (targetId: string) => void
}

export const TargetSelector: React.FC<TargetSelectorProps> = ({
  targetOptions,
  potentialFriends,
  selectedTarget,
  onTargetSelect,
  onSendFriendRequest,
}) => {
  const allPossibleTargets = [
    ...targetOptions, // Current friends
    ...potentialFriends.map(pf => pf.id), // Potential friends
  ]

  const handleTargetPress = (target: string) => {
    if (targetOptions.includes(target)) {
      // This is a friend - select for messaging
      onTargetSelect(target)
    } else {
      // This is a potential friend - send friend request
      onSendFriendRequest(target)
    }
  }

  return (
    <>
      {allPossibleTargets.length > 0 ? (
        <View style={styles.targetSelector}>
          <Text style={styles.targetLabel}>Friends & Available Users:</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            {allPossibleTargets.map(target => {
              const isFriend = targetOptions.includes(target)
              const isSelected = selectedTarget === target
              return (
                <TouchableOpacity
                  key={target}
                  style={[
                    styles.targetButton,
                    isSelected && styles.selectedTargetButton,
                    !isFriend && styles.potentialFriendButton,
                  ]}
                  onPress={() => handleTargetPress(target)}>
                  <Text
                    style={[
                      styles.targetButtonText,
                      isSelected && styles.selectedTargetButtonText,
                      !isFriend && styles.potentialFriendButtonText,
                    ]}>
                    {isFriend ? '👫' : '👥'} {target}
                    {!isFriend && (
                      <Text style={styles.actionHint}> (tap to add)</Text>
                    )}
                  </Text>
                </TouchableOpacity>
              )
            })}
          </ScrollView>
        </View>
      ) : (
        <View style={styles.noTargetsContainer}>
          <Text style={styles.noTargetsText}>
            No friends or available users to chat with.
          </Text>
        </View>
      )}
    </>
  )
}

const styles = StyleSheet.create({
  targetSelector: {
    padding: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    backgroundColor: 'rgba(255,255,255,0.9)',
  },
  targetLabel: {
    fontSize: typography.sizes.md,
    fontWeight: typography.weights.semibold,
    color: colors.text.secondary,
    marginBottom: 6,
  },
  targetButton: {
    backgroundColor: '#f0f0f0',
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    borderRadius: 12,
    marginRight: spacing.sm,
    ...commonStyles.border,
  },
  selectedTargetButton: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  targetButtonText: {
    fontSize: typography.sizes.md,
    fontWeight: typography.weights.medium,
    color: colors.text.primary,
  },
  selectedTargetButtonText: {
    color: colors.text.white,
    fontWeight: typography.weights.semibold,
  },
  potentialFriendButton: {
    backgroundColor: '#fff3cd',
    borderColor: '#ffc107',
  },
  potentialFriendButtonText: {
    color: '#856404',
  },
  actionHint: {
    fontSize: typography.sizes.sm,
    fontStyle: 'italic',
    opacity: 0.8,
  },
  noTargetsContainer: {
    padding: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
    backgroundColor: 'rgba(255,193,7,0.1)',
  },
  noTargetsText: {
    fontSize: typography.sizes.md,
    color: colors.warning,
    textAlign: 'center',
    fontStyle: 'italic',
  },
})
