import {Dimensions} from 'react-native'

const {width: screenWidth} = Dimensions.get('window')

export const CHAT_WIDTH = screenWidth - 32
export const SLIDE_MARGIN = 8

export const USER_THEMES = [
  {name: 'Alice', color: '#667eea'},
  {name: 'Bob', color: '#f093fb'},
  {name: 'Charlie', color: '#4facfe'},
  {name: 'Diana', color: '#43e97b'},
  {name: 'Eve', color: '#fa709a'},
  {name: 'Frank', color: '#a8edea'},
] as const

export const MAX_CHAT_INSTANCES = USER_THEMES.length

export interface ChatMeta {
  id: string
  userName: string
  backgroundColor: string
}
