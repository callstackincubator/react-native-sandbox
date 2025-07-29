import React from 'react'
import {StyleSheet, Text, TouchableOpacity, View} from 'react-native'

import {colors, commonStyles, spacing, typography} from '../styles/common'

interface NotificationsListProps {
  notifications: string[]
  onClearNotification: (index: number) => void
}

export const NotificationsList: React.FC<NotificationsListProps> = ({
  notifications,
  onClearNotification,
}) => {
  if (notifications.length === 0) {
    return null
  }

  return (
    <View style={styles.container}>
      {notifications.map((notification, index) => (
        <View key={index} style={styles.notification}>
          <Text style={styles.notificationText}>{notification}</Text>
          <TouchableOpacity onPress={() => onClearNotification(index)}>
            <Text style={styles.notificationClose}>×</Text>
          </TouchableOpacity>
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
    backgroundColor: 'rgba(255,255,255,0.8)',
  },
  notification: {
    ...commonStyles.row,
    justifyContent: 'space-between',
    backgroundColor: '#f0f0f0',
    padding: spacing.sm + 2, // 10px
    ...commonStyles.rounded,
    marginBottom: spacing.sm,
    ...commonStyles.border,
  },
  notificationText: {
    flex: 1,
    fontSize: typography.sizes.md + 1, // 13px
    color: colors.text.primary,
    marginRight: spacing.sm + 2, // 10px
  },
  notificationClose: {
    fontSize: typography.sizes.xl,
    color: colors.text.secondary,
    fontWeight: typography.weights.bold,
  },
})
