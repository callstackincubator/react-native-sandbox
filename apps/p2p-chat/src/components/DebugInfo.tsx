import React from 'react'
import {StyleSheet, Text, View} from 'react-native'

import {colors, spacing, typography} from '../styles/common'

interface DebugInfoProps {
  userId: string
  targetOptions: string[]
  potentialFriendsCount: number
  messageCount: number
}

export const DebugInfo: React.FC<DebugInfoProps> = ({
  userId,
  targetOptions,
  potentialFriendsCount,
  messageCount,
}) => {
  return (
    <View style={styles.debugInfo}>
      <Text style={styles.debugText}>
        ID: {userId} • Friends: [{targetOptions.join(', ')}] • Potential:{' '}
        {potentialFriendsCount} • Messages: {messageCount}
      </Text>
    </View>
  )
}

const styles = StyleSheet.create({
  debugInfo: {
    padding: spacing.sm,
    backgroundColor: 'rgba(0,0,0,0.05)',
  },
  debugText: {
    fontSize: typography.sizes.xs,
    color: colors.text.secondary,
    textAlign: 'center',
    fontFamily: 'monospace',
  },
})
