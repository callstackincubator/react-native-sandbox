import {useCallback, useState} from 'react'
import {NativeScrollEvent, NativeSyntheticEvent} from 'react-native'

import {ChatMeta} from '../constants'
import {calculateBackgroundColor, calculateSlideIndex} from '../utils'

interface UseScrollColorInterpolationProps {
  chatInstances: ChatMeta[]
  scrollStep: number // Width of each scroll step (e.g., screen width for full-width slides)
  onIndexChange: (index: number) => void
}

export const useScrollColorInterpolation = ({
  chatInstances,
  scrollStep,
  onIndexChange,
}: UseScrollColorInterpolationProps) => {
  // State for smooth color interpolation
  const [currentBackgroundColor, setCurrentBackgroundColor] = useState(
    chatInstances[0]?.backgroundColor || '#667eea'
  )

  const onScroll = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      const scrollX = event.nativeEvent.contentOffset.x

      // Update current index
      const slideIndex = calculateSlideIndex(scrollX, scrollStep)
      onIndexChange(slideIndex)

      // Calculate and update background color
      const backgroundColor = calculateBackgroundColor(
        scrollX,
        scrollStep,
        chatInstances
      )
      setCurrentBackgroundColor(backgroundColor)
    },
    [chatInstances, scrollStep, onIndexChange]
  )

  return {
    currentBackgroundColor,
    onScroll,
  }
}
