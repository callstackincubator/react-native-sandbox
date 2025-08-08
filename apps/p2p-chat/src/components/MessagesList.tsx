import React, {useEffect, useRef} from 'react'
import {ScrollView, StyleSheet, Text, View} from 'react-native'

import {colors, commonStyles, spacing, typography} from '../styles/common'
import {Message} from '../types'

interface MessagesListProps {
  messages: Message[]
  selectedTarget: string
}

export const MessagesList: React.FC<MessagesListProps> = ({
  messages,
  selectedTarget,
}) => {
  const scrollRef = useRef<ScrollView>(null)

  useEffect(() => {
    // Auto-scroll to bottom when new messages arrive
    if (messages.length > 0) {
      setTimeout(() => {
        scrollRef.current?.scrollToEnd({animated: true})
      }, 100)
    }
  }, [messages])

  const formatTime = (timestamp: number) => {
    return new Date(timestamp).toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <ScrollView
      ref={scrollRef}
      style={styles.container}
      showsVerticalScrollIndicator={false}>
      {messages.length === 0 && (
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>
            {selectedTarget
              ? `Send a message to start chatting with ${selectedTarget}!`
              : 'Select or enter a target to start messaging!'}
          </Text>
        </View>
      )}

      {messages.map(message => (
        <View
          key={message.id}
          style={[
            styles.messageBubble,
            message.type === 'sent'
              ? styles.sentMessage
              : message.type === 'error'
                ? styles.errorMessage
                : styles.receivedMessage,
          ]}>
          {message.type === 'error' && (
            <View style={styles.errorIcon}>
              <Text style={styles.errorIconText}>⚠️</Text>
            </View>
          )}
          <Text
            style={[
              styles.messageText,
              message.type === 'sent' && styles.sentMessageText,
              message.type === 'error' && styles.errorMessageText,
            ]}>
            {message.text}
          </Text>
          <Text
            style={[
              styles.messageTime,
              message.type === 'sent' && styles.sentMessageTime,
              message.type === 'error' && styles.errorMessageTime,
            ]}>
            {message.sender} • {formatTime(message.timestamp)}
          </Text>
        </View>
      ))}
    </ScrollView>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: spacing.sm,
    backgroundColor: 'rgba(255,255,255,0.3)',
  },
  emptyState: {
    flex: 1,
    ...commonStyles.centered,
    padding: spacing.xl,
  },
  emptyText: {
    fontSize: typography.sizes.md + 1, // 13px
    color: colors.text.secondary,
    textAlign: 'center',
    fontStyle: 'italic',
  },
  messageBubble: {
    marginVertical: 3,
    padding: spacing.sm + 2, // 10px
    borderRadius: 14,
    maxWidth: '80%',
  },
  sentMessage: {
    alignSelf: 'flex-end',
    backgroundColor: colors.primary,
  },
  receivedMessage: {
    alignSelf: 'flex-start',
    backgroundColor: 'rgba(255,255,255,0.95)',
    ...commonStyles.border,
  },
  errorMessage: {
    alignSelf: 'flex-start',
    backgroundColor: '#ffebee', // Light red background
    borderWidth: 1,
    borderColor: colors.error, // Red border
  },
  errorIcon: {
    alignSelf: 'flex-start',
    marginLeft: 5,
    marginTop: -5,
    backgroundColor: colors.error,
    borderRadius: 8,
    padding: 2,
  },
  errorIconText: {
    fontSize: typography.sizes.lg,
    color: colors.text.white,
  },
  messageText: {
    fontSize: typography.sizes.lg,
    color: colors.text.primary,
    marginBottom: 3,
  },
  sentMessageText: {
    color: colors.text.white,
  },
  errorMessageText: {
    color: '#d32f2f', // Darker red for error text
  },
  messageTime: {
    fontSize: typography.sizes.sm,
    color: colors.text.secondary,
    fontWeight: typography.weights.medium,
  },
  sentMessageTime: {
    color: 'rgba(255,255,255,0.8)',
  },
  errorMessageTime: {
    color: colors.error, // Red for error time
  },
})
