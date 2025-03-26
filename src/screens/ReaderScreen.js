import React, { useEffect, useState, useRef } from 'react'
import {
  View,
  Text,
  TouchableOpacity,
  Modal,
  StyleSheet,
  Switch,
  ScrollView,
  Animated
} from 'react-native'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { WebView } from 'react-native-webview'
import * as FileSystem from 'expo-file-system'
import { Picker } from '@react-native-picker/picker'
import { Ionicons } from '@expo/vector-icons'
import Slider from '@react-native-community/slider'
import { Alert } from 'react-native'
const SETTINGS_KEY = 'reader_settings'
const PROGRESS_KEY = 'reading_progress'

const ReaderScreen = ({ route }) => {
  const { filePath } = route.params
  const [htmlContent, setHtmlContent] = useState('')
  const [modalVisible, setModalVisible] = useState(false)
  const [menuVisible, setMenuVisible] = useState(false)
  const [darkMode, setDarkMode] = useState(false)
  const [fontSize, setFontSize] = useState(16)
  const [fontFamily, setFontFamily] = useState('serif')
  const [textColor, setTextColor] = useState('#000')
  const [chapters, setChapters] = useState([])
  const webViewRef = useRef(null)
  const slideAnim = useRef(new Animated.Value(-250)).current

  useEffect(() => {
    const loadFile = async () => {
      try {
        const formattedPath = filePath.startsWith('file://')
          ? filePath
          : 'file://' + filePath
        const fileContent = await FileSystem.readAsStringAsync(formattedPath, {
          encoding: FileSystem.EncodingType.UTF8
        })
        setHtmlContent(fileContent)
        extractChapters(fileContent)
      } catch (error) {
        console.error(`Error loading file: ${filePath}`, error)
      }
    }
    loadFile()
    loadSettings()
    loadProgress()
  }, [filePath])
  useEffect(() => {
    const autoSaveInterval = setInterval(saveProgress, 6000)
    return () => clearInterval(autoSaveInterval)
  }, [htmlContent])

  useEffect(() => {
    const saveProgressInterval = setInterval(saveProgress, 300000)
    return () => clearInterval(saveProgressInterval)
  }, [htmlContent])

  const extractChapters = html => {
    const regex = /<(h[1-4])(?:[^>]*)>(.*?)<\/\1>/gi
    let foundChapters = []
    let match
    while ((match = regex.exec(html)) !== null) {
      const chapterId = `chapter-${foundChapters.length}`
      foundChapters.push({ text: match[2], id: chapterId })
    }
    setChapters(foundChapters)
  }

  const loadSettings = async () => {
    const savedSettings = await AsyncStorage.getItem(SETTINGS_KEY)
    if (savedSettings) {
      const { darkMode, fontSize, fontFamily, textColor } =
        JSON.parse(savedSettings)
      setDarkMode(darkMode)
      setFontSize(fontSize)
      setFontFamily(fontFamily)
      setTextColor(textColor)
    }
  }

  const saveSettings = async () => {
    await AsyncStorage.setItem(
      SETTINGS_KEY,
      JSON.stringify({ darkMode, fontSize, fontFamily, textColor })
    )
  }

  const loadProgress = async () => {
    const savedProgress = await AsyncStorage.getItem(PROGRESS_KEY)
    if (savedProgress && webViewRef.current) {
      webViewRef.current.injectJavaScript(
        `window.scrollTo(0, ${savedProgress});`
      )
      console.log('loaded progress:', savedProgress)
    }
  }

  const saveProgress = async () => {
    if (webViewRef.current) {
      const jsCode = `(function() {
        window.ReactNativeWebView.postMessage(window.pageYOffset.toString());
      })();`
      webViewRef.current.injectJavaScript(jsCode)
    }
  }

  const handleMessage = event => {
    const progress = event.nativeEvent.data
    console.log('saved progress:', progress)
    AsyncStorage.setItem(PROGRESS_KEY, event.nativeEvent.data)
  }

  const scrollToChapter = chapterId => {
    if (webViewRef.current) {
      const jsCode = `
        (function() {
          const headings = document.querySelectorAll("h1, h2, h3, h4");
          headings.forEach((heading, index) => {
            heading.id = "chapter-" + index;
          });
          const element = document.getElementById(${JSON.stringify(chapterId)});
          if (element) {
            element.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        })();
      `
      webViewRef.current.injectJavaScript(jsCode)
    }
    toggleMenu()
  }

  const injectedCSS = `
    <style>
      body { background-color: ${darkMode ? '#121212' : '#fff'}; color: ${
    darkMode ? '#eee' : textColor
  }; }
      .userstuff { font-size: ${fontSize}px; font-family: ${fontFamily}; }
      h1, h2, h3, h4 { scroll-margin-top: 20px; }
    </style>
    <script>
      document.addEventListener("DOMContentLoaded", function() {
        const headings = document.querySelectorAll("h1, h2, h3, h4");
        headings.forEach((heading, index) => {
          heading.id = "chapter-" + index;
        });
      });
    </script>
  `

  const toggleMenu = () => {
    Animated.timing(slideAnim, {
      toValue: menuVisible ? -250 : 0,
      duration: 300,
      useNativeDriver: true
    }).start()
    setMenuVisible(!menuVisible)
  }

  return (
    <View style={{ flex: 1 }}>
      {htmlContent ? (
        <WebView
          ref={webViewRef}
          source={{ html: injectedCSS + htmlContent }}
          style={{ flex: 1 }}
          onMessage={handleMessage}
        />
      ) : (
        <Text style={{ textAlign: 'center', marginTop: 20 }}>Loading...</Text>
      )}

      <TouchableOpacity style={styles.menuButton} onPress={toggleMenu}>
        <Ionicons name='menu' size={24} color='white' />
      </TouchableOpacity>

      <Animated.View
        style={[
          styles.menuContainer,
          { transform: [{ translateX: slideAnim }] }
        ]}
      >
        <ScrollView>
          {chapters.map((chapter, index) => (
            <TouchableOpacity
              key={index}
              onPress={() => scrollToChapter(chapter.id)}
            >
              <Text style={styles.chapterItem}>{chapter.text}</Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </Animated.View>

      <TouchableOpacity
        style={styles.floatingButton}
        onPress={() => setModalVisible(true)}
      >
        <Ionicons name='settings' size={24} color='white' />
      </TouchableOpacity>

      <Modal visible={modalVisible} transparent={true} animationType='fade'>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Settings</Text>

            {/* darkmode */}
            <View style={styles.settingItem}>
              <Text style={styles.settingLabel}>Dark Mode</Text>
              <Switch
                value={darkMode}
                onValueChange={value => setDarkMode(value)}
              />
            </View>

            {/* font size */}
            <View style={styles.settingItem}>
              <Text style={styles.settingLabel}>Font Size: {fontSize}px</Text>
              <Slider
                style={{ flex: 1 }}
                minimumValue={5}
                maximumValue={100}
                value={fontSize}
                step={1}
                onSlidingComplete={value => {
                  const roundedValue = Math.round(value)
                  setFontSize(roundedValue)
                  if (webViewRef.current) {
                    const jsCode = `
                    (function() {
                      document.body.style.fontSize = "${roundedValue}px";
                    })();
                  `
                    webViewRef.current.injectJavaScript(jsCode)
                  }
                }}
                minimumTrackTintColor='#007AFF'
                maximumTrackTintColor='#000'
              />
            </View>

            {/* Font */}
            <View style={styles.settingItem}>
              <Text style={styles.settingLabel}>Font Family</Text>
              <Picker
                style={styles.picker}
                selectedValue={fontFamily}
                onValueChange={value => setFontFamily(value)}
                mode='dropdown'
              >
                <Picker.Item label='Serif' value='serif' />
                <Picker.Item label='Sans-serif' value='sans-serif' />
                <Picker.Item label='Monospace' value='monospace' />
              </Picker>
            </View>

            {/* text color */}
            <View style={styles.settingItem}>
              <Text style={styles.settingLabel}>Text Color</Text>
              <Picker
                style={styles.picker}
                selectedValue={textColor}
                onValueChange={value => setTextColor(value)}
                mode='dropdown'
              >
                <Picker.Item label='Black' value='#000000' />
                <Picker.Item label='White' value='#ffffff' />
                <Picker.Item label='Red' value='#ff0000' />
                <Picker.Item label='Blue' value='#0000ff' />
                <Picker.Item label='Green' value='#008000' />
              </Picker>
            </View>

            {/* progress buttons */}
            <View style={styles.progressButtonContainer}>
              {/* save */}
              <TouchableOpacity
                style={[styles.progressButton, { backgroundColor: 'green' }]}
                onPress={() => {
                  saveProgress()
                  console.log('Progress saved')
                }}
              >
                <Text style={styles.progressButtonText}>Save</Text>
              </TouchableOpacity>

              {/* load */}
              <TouchableOpacity
                style={[styles.progressButton, { backgroundColor: 'blue' }]}
                onPress={() => {
                  loadProgress()
                  console.log('Progress loaded')
                }}
              >
                <Text style={styles.progressButtonText}>Load</Text>
              </TouchableOpacity>

              {/* reset */}
              <TouchableOpacity
                style={[styles.progressButton, { backgroundColor: 'red' }]}
                onPress={() => {
                  Alert.alert(
                    'Confirm Reset',
                    'Are you sure you want to reset progress?',
                    [
                      {
                        text: 'Cancel',
                        onPress: () => console.log('Reset cancelled'),
                        style: 'cancel'
                      },
                      {
                        text: 'Reset',
                        style: 'destructive',
                        onPress: async () => {
                          try {
                            await AsyncStorage.setItem(PROGRESS_KEY, '0')
                            console.log('Progress reset')
                          } catch (error) {
                            console.error('Error resetting progress:', error)
                          }
                        }
                      }
                    ],
                    { cancelable: true }
                  )
                }}
              >
                <Text style={styles.progressButtonText}>Reset</Text>
              </TouchableOpacity>
            </View>

            <TouchableOpacity
              style={styles.closeButton}
              onPress={() => {
                setModalVisible(false)
                saveSettings()
              }}
            >
              <Text style={styles.closeButtonText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  )
}

const styles = StyleSheet.create({
  menuButton: {
    position: 'absolute',
    top: 40,
    left: 20,
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 30,
    elevation: 5
  },
  menuContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: 250,
    height: '100%',
    backgroundColor: '#333',
    paddingTop: 50
  },
  chapterItem: {
    color: 'white',
    padding: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#555'
  },
  floatingButton: {
    position: 'absolute',
    top: 40,
    right: 20,
    backgroundColor: '#007AFF',
    padding: 12,
    borderRadius: 30,
    elevation: 5
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)', // semi-transparent overlay
    justifyContent: 'center',
    alignItems: 'center'
  },
  modalContent: {
    width: '80%',
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 20,
    elevation: 10
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center'
  },
  settingItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 15
  },
  settingLabel: {
    fontSize: 16
  },
  picker: {
    width: 120
  },
  closeButton: {
    marginTop: 20,
    backgroundColor: '#007AFF',
    paddingVertical: 10,
    borderRadius: 5,
    alignItems: 'center'
  },
  closeButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold'
  },
  progressButtonContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginVertical: 15
  },
  progressButton: {
    flex: 1,
    marginHorizontal: 5,
    paddingVertical: 10,
    borderRadius: 5,
    alignItems: 'center'
  },
  progressButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold'
  }
})

export default ReaderScreen
