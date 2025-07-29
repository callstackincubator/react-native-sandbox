import {StyleSheet} from 'react-native'

// Color Palette
export const colors = {
  primary: '#2196f3',
  success: '#4caf50',
  error: '#f44336',
  warning: '#ff9800',
  background: '#f8f9fa',
  surface: '#ffffff',
  text: {
    primary: '#1a1a1a',
    secondary: '#666',
    light: '#999',
    white: '#fff',
  },
  border: 'rgba(0,0,0,0.1)',
  shadow: '#000',
}

// Spacing
export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
}

// Typography
export const typography = {
  sizes: {
    xs: 9,
    sm: 10,
    md: 12,
    lg: 14,
    xl: 16,
    xxl: 18,
  },
  weights: {
    normal: '400' as const,
    medium: '500' as const,
    semibold: '600' as const,
    bold: 'bold' as const,
  },
}

// Common Styles
export const commonStyles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.surface,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  centered: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  shadow: {
    shadowColor: colors.shadow,
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  border: {
    borderWidth: 1,
    borderColor: colors.border,
  },
  rounded: {
    borderRadius: 8,
  },
  roundedLarge: {
    borderRadius: 12,
  },
})

// Button Styles
export const buttonStyles = StyleSheet.create({
  base: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  primary: {
    backgroundColor: colors.primary,
  },
  success: {
    backgroundColor: colors.success,
  },
  error: {
    backgroundColor: colors.error,
  },
  text: {
    color: colors.text.white,
    fontSize: typography.sizes.lg,
    fontWeight: typography.weights.semibold,
  },
  disabled: {
    backgroundColor: '#ccc',
    opacity: 0.5,
  },
})
