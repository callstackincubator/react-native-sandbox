import {Dimensions} from 'react-native'

const {width: screenWidth} = Dimensions.get('window')

export const CHAT_WIDTH = screenWidth - 40 // Account for padding

export const PRESET_USERS = [
  {name: 'Alice', color: '#e3f2fd'},
  {name: 'Bob', color: '#f3e5f5'},
  {name: 'Charlie', color: '#e8f5e8'},
  {name: 'Diana', color: '#fff3e0'},
  {name: 'Eve', color: '#fce4ec'},
  {name: 'Frank', color: '#e0f2f1'},
] as const

export const MAX_CHAT_INSTANCES = PRESET_USERS.length
export const MIN_CHAT_INSTANCES = 1

export interface ChatInstance {
  id: string
  userName: string
  backgroundColor: string
}
