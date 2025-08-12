import {Dimensions, StyleSheet} from 'react-native'

import {CHAT_WIDTH, SLIDE_MARGIN} from '../constants'

const {width: screenWidth} = Dimensions.get('window')

export const carouselStyles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  carouselContainer: {
    flex: 1,
  },
  carousel: {
    flex: 1,
    backgroundColor: 'transparent',
  },
  carouselContent: {
    paddingHorizontal: SLIDE_MARGIN,
  },
  chatSlide: {
    width: screenWidth, // Full screen width for proper paging
    flex: 1,
    paddingHorizontal: SLIDE_MARGIN, // Use padding instead of margin
    alignItems: 'center', // Center the content
    justifyContent: 'center',
  },
  chatContent: {
    width: CHAT_WIDTH, // The actual chat content width
    flex: 1,
    backgroundColor: '#ffffff',
    borderRadius: 12,
    marginVertical: 8,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 4},
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
    overflow: 'hidden',
  },
  chatHeader: {
    position: 'relative',
    backgroundColor: '#ffffff',
    paddingHorizontal: 15,
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(0,0,0,0.1)',
    minHeight: 60,
    justifyContent: 'center',
    alignItems: 'center',
  },
  chatHeaderContent: {
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
  },
  chatTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1a1a1a',
    marginBottom: 2,
  },
  chatSubtitle: {
    fontSize: 12,
    color: '#666',
    fontWeight: '500',
  },
  chatContainer: {
    flex: 1,
    overflow: 'hidden',
  },
  sandbox: {
    flex: 1,
    overflow: 'hidden',
  },
  deleteButton: {
    position: 'absolute',
    left: 15,
    top: 15,
    padding: 5,
    borderRadius: 10,
    backgroundColor: '#f44336',
    width: 30,
    height: 30,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1,
  },
  deleteButtonText: {
    color: '#ffffff',
    fontSize: 20,
    fontWeight: 'bold',
    margin: -10,
  },
  deleteButtonDisabled: {
    opacity: 0.5,
  },
  addChatCard: {
    width: '45%', // Make it 45% of the slide width
    height: '60%', // Make it 60% of the slide height
    backgroundColor: '#f8f9fa',
    borderRadius: 12,
    padding: 20, // Reduced padding
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 2},
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    borderWidth: 2,
    borderColor: '#dee2e6',
    borderStyle: 'dashed',
    alignSelf: 'center', // Center horizontally in the slide
  },
  addChatContent: {
    alignItems: 'center',
  },
  addChatIcon: {
    fontSize: 30, // Reduced from 40
    color: '#6c757d',
    marginBottom: 8, // Reduced margin
  },
  addChatIconDisabled: {
    opacity: 0.5,
  },
  addChatText: {
    fontSize: 16, // Reduced from 18
    fontWeight: 'bold',
    color: '#6c757d',
    marginBottom: 4, // Reduced margin
  },
  addChatTextDisabled: {
    opacity: 0.5,
  },
  addChatLimitText: {
    fontSize: 12,
    color: '#adb5bd',
  },

  pageIndicators: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 15,
    gap: 8,
  },
  pageIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#ccc',
  },
  activePageIndicator: {
    backgroundColor: '#2196f3',
    width: 12,
    height: 8,
  },
  info: {
    backgroundColor: 'rgba(255,255,255,0.9)',
    margin: 10,
    padding: 12,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: {width: 0, height: 1},
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 1,
  },
  infoText: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    lineHeight: 18,
  },
})
