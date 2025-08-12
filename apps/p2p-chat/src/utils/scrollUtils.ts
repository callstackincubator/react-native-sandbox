import {ChatMeta} from '../constants'
import {interpolateColor} from './colorUtils'

export const calculateSlideIndex = (
  scrollX: number,
  slideWidth: number
): number => {
  return Math.round(scrollX / slideWidth)
}

export const calculateInterpolationProgress = (
  scrollX: number,
  slideWidth: number
): {
  currentSlideIndex: number
  factor: number
} => {
  const progress = scrollX / slideWidth
  const currentSlideIndex = Math.floor(progress)
  const factor = progress - currentSlideIndex

  return {currentSlideIndex, factor}
}

export const getSlideColors = (
  currentSlideIndex: number,
  chatInstances: ChatMeta[]
): {currentSlideColor: string; nextSlideColor: string} => {
  const addChatColor = '#f8f9fa' // Light gray for add chat slide

  let currentSlideColor = '#667eea'
  let nextSlideColor = '#667eea'

  if (currentSlideIndex < chatInstances.length) {
    // Normal chat instance
    currentSlideColor =
      chatInstances[currentSlideIndex]?.backgroundColor || '#667eea'

    if (currentSlideIndex + 1 < chatInstances.length) {
      // Next slide is another chat instance
      nextSlideColor =
        chatInstances[currentSlideIndex + 1]?.backgroundColor ||
        currentSlideColor
    } else {
      // Next slide is the add chat slide
      nextSlideColor = addChatColor
    }
  } else {
    // Currently on add chat slide
    currentSlideColor = addChatColor
    nextSlideColor = addChatColor
  }

  return {currentSlideColor, nextSlideColor}
}

export const calculateBackgroundColor = (
  scrollX: number,
  slideWidth: number,
  chatInstances: ChatMeta[]
): string => {
  const {currentSlideIndex, factor} = calculateInterpolationProgress(
    scrollX,
    slideWidth
  )
  const {currentSlideColor, nextSlideColor} = getSlideColors(
    currentSlideIndex,
    chatInstances
  )

  const totalSlides = chatInstances.length + 1 // +1 for add chat slide

  if (currentSlideIndex < totalSlides - 1 && factor > 0) {
    return interpolateColor(currentSlideColor, nextSlideColor, factor)
  } else {
    return currentSlideColor
  }
}
