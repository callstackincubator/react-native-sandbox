import React from 'react'
import {Pressable, StyleSheet, Text, TextInput, View} from 'react-native'

import {buttonStyles, colors, spacing, typography} from '../styles/common'

interface MessageInputProps {
  inputText: string
  selectedTarget: string
  isFriend: boolean
  onInputChange: (text: string) => void
  onSendMessage: () => void
}

export const MessageInput: React.FC<MessageInputProps> = ({
  inputText,
  selectedTarget,
  isFriend,
  onInputChange,
  onSendMessage,
}) => {
  const canSend = inputText.trim() && selectedTarget.trim() && isFriend

  const handleSubmit = () => {
    if (canSend) {
      onSendMessage()
    }
  }

  const placeholder = !selectedTarget
    ? 'Select a user above...'
    : !isFriend
      ? `Add ${selectedTarget} as friend first`
      : `Message ${selectedTarget}...`

  return (
    <View style={styles.container}>
      <TextInput
        style={[styles.textInput, !isFriend && styles.textInputDisabled]}
        value={inputText}
        onChangeText={onInputChange}
        placeholder={placeholder}
        editable={isFriend}
        multiline
        maxLength={500}
        onSubmitEditing={handleSubmit}
        blurOnSubmit={false}
      />
      <Pressable
        style={[
          buttonStyles.base,
          buttonStyles.primary,
          styles.sendButton,
          !canSend && buttonStyles.disabled,
        ]}
        onPress={handleSubmit}
        disabled={!canSend}>
        <Text style={[buttonStyles.text, styles.sendButtonText]}>Send</Text>
      </Pressable>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    padding: spacing.md,
    borderTopWidth: 1,
    borderTopColor: colors.border,
    backgroundColor: 'rgba(255,255,255,0.95)',
  },
  textInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.2)',
    borderRadius: 18,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    marginRight: spacing.sm,
    maxHeight: 80,
    backgroundColor: colors.surface,
    fontSize: typography.sizes.lg,
  },
  textInputDisabled: {
    backgroundColor: '#f5f5f5',
    opacity: 0.6,
  },
  sendButton: {
    borderRadius: 18,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm + 2,
  },
  sendButtonText: {
    fontSize: typography.sizes.lg,
  },
})
