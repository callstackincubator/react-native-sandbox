import {Dimensions} from 'react-native'

const {width: screenWidth} = Dimensions.get('window')

// Carousel slide dimensions
export const CHAT_WIDTH = screenWidth - 32 // Account for container margins
export const SLIDE_MARGIN = 8 // Horizontal margin between slides

export const USER_THEMES = [
  {name: 'Alice', color: '#667eea'},
  {name: 'Bob', color: '#f093fb'},
  {name: 'Charlie', color: '#4facfe'},
  {name: 'Diana', color: '#43e97b'},
  {name: 'Eve', color: '#fa709a'},
  {name: 'Frank', color: '#a8edea'},
] as const

export const MAX_CHAT_INSTANCES = USER_THEMES.length
export const MIN_CHAT_INSTANCES = 1

export interface ChatMeta {
  id: string
  userName: string
  backgroundColor: string
}
