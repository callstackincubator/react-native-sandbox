import React from 'react'
import {StyleSheet, Text, TextInput, TouchableOpacity, View} from 'react-native'

import {buttonStyles, colors, spacing, typography} from '../styles/common'

interface MessageInputProps {
  inputText: string
  selectedTarget: string
  onInputChange: (text: string) => void
  onSendMessage: () => void
}

export const MessageInput: React.FC<MessageInputProps> = ({
  inputText,
  selectedTarget,
  onInputChange,
  onSendMessage,
}) => {
  const canSend = inputText.trim() && selectedTarget.trim()

  const handleSubmit = () => {
    if (canSend) {
      onSendMessage()
    }
  }

  return (
    <View style={styles.container}>
      <TextInput
        style={styles.textInput}
        value={inputText}
        onChangeText={onInputChange}
        placeholder={
          selectedTarget
            ? `Message ${selectedTarget}...`
            : 'Enter target above, then type message...'
        }
        multiline
        maxLength={500}
        onSubmitEditing={handleSubmit}
        blurOnSubmit={false}
      />
      <TouchableOpacity
        style={[
          buttonStyles.base,
          buttonStyles.primary,
          styles.sendButton,
          !canSend && buttonStyles.disabled,
        ]}
        onPress={handleSubmit}
        disabled={!canSend}>
        <Text style={[buttonStyles.text, styles.sendButtonText]}>Send</Text>
      </TouchableOpacity>
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
  sendButton: {
    borderRadius: 18,
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.sm + 2, // 10px
  },
  sendButtonText: {
    fontSize: typography.sizes.lg,
  },
})
