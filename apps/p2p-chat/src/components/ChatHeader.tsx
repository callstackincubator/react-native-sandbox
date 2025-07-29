import React from 'react'
import {StyleSheet, Text, View} from 'react-native'

import {colors, commonStyles, spacing, typography} from '../styles/common'

interface ChatHeaderProps {
  userName: string
  isConnected: boolean
}

export const ChatHeader: React.FC<ChatHeaderProps> = ({
  userName,
  isConnected,
}) => {
  return (
    <View style={styles.header}>
      <Text style={styles.headerTitle}>{userName}</Text>
      <View
        style={[
          styles.statusDot,
          {
            backgroundColor: isConnected ? colors.success : colors.warning,
          },
        ]}
      />
    </View>
  )
}

const styles = StyleSheet.create({
  header: {
    ...commonStyles.row,
    justifyContent: 'center',
    padding: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  headerTitle: {
    fontSize: typography.sizes.xl,
    fontWeight: typography.weights.bold,
    color: colors.text.primary,
  },
  statusDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginLeft: 6,
  },
})
