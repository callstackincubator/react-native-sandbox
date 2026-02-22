import React from 'react'
import {Pressable, ScrollView, StyleSheet, Text, View} from 'react-native'

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
    ...targetOptions,
    ...potentialFriends.map(pf => pf.id),
  ]

  const handleTargetPress = (target: string) => {
    if (targetOptions.includes(target)) {
      onTargetSelect(target)
    } else {
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
                <Pressable
                  key={target}
                  style={[
                    styles.targetButton,
                    isFriend && styles.friendButton,
                    isFriend && isSelected && styles.selectedFriendButton,
                    !isFriend && styles.potentialFriendButton,
                  ]}
                  onPress={() => handleTargetPress(target)}>
                  <Text
                    style={[
                      styles.targetButtonText,
                      isFriend && styles.friendButtonText,
                      isFriend && isSelected && styles.selectedFriendButtonText,
                      !isFriend && styles.potentialFriendButtonText,
                    ]}>
                    {isFriend ? '👫' : '👥'} {target}
                    {!isFriend && (
                      <Text style={styles.actionHint}> (tap to add)</Text>
                    )}
                  </Text>
                </Pressable>
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
  friendButton: {
    backgroundColor: 'rgba(76, 175, 80, 0.12)',
    borderColor: 'rgba(76, 175, 80, 0.4)',
  },
  selectedFriendButton: {
    backgroundColor: 'rgba(76, 175, 80, 0.25)',
    borderColor: '#4caf50',
  },
  targetButtonText: {
    fontSize: typography.sizes.md,
    fontWeight: typography.weights.medium,
    color: colors.text.primary,
  },
  friendButtonText: {
    color: '#2e7d32',
  },
  selectedFriendButtonText: {
    color: '#1b5e20',
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
