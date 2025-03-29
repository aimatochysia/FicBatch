import React, { useState, useEffect, useRef } from 'react'
import {
  View,
  Text,
  TextInput,
  Button,
  ScrollView,
  Alert,
  StyleSheet,
  ActivityIndicator,
  TouchableOpacity
} from 'react-native'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { downloadAO3Work } from '../utils/downloader'
import { Ionicons } from '@expo/vector-icons'

const HomeScreen = ({ navigation }) => {
  const [links, setLinks] = useState('')
  const [downloadQueue, setDownloadQueue] = useState([])
  const [isDownloading, setIsDownloading] = useState(false)
  const [darkMode, setDarkMode] = useState(false)
  const scrollViewRef = useRef(null)

  useEffect(() => {
    ;(async () => {
      const savedMode = await AsyncStorage.getItem('darkMode')
      if (savedMode !== null) {
        setDarkMode(savedMode === 'true')
      }
    })()
  }, [])

  const toggleMode = async () => {
    const newMode = !darkMode
    setDarkMode(newMode)
    await AsyncStorage.setItem('darkMode', newMode.toString())
  }

  const parseLinks = text => {
    const linkArray = text.split(/\s+/).filter(link => link)
    return linkArray.map((link, index) => ({
      id: index.toString(),
      link,
      status: 'pending'
    }))
  }

  const handleLinksChange = text => {
    setLinks(text)
    const items = parseLinks(text)
    setDownloadQueue(items)
  }

  const handleClearInput = () => {
    setLinks('')
    setDownloadQueue([])
  }

  const handleDownload = async () => {
    if (!links.trim()) {
      Alert.alert('Error', 'Enter at least one link.')
      return
    }

    const items = parseLinks(links)
    setDownloadQueue(items)
    setIsDownloading(true)

    for (const item of items) {
      setDownloadQueue(queue =>
        queue.map(q => (q.id === item.id ? { ...q, status: 'downloading' } : q))
      )
      scrollViewRef.current?.scrollToEnd({ animated: true })

      try {
        await downloadAO3Work(item.link)
        setDownloadQueue(queue =>
          queue.map(q =>
            q.id === item.id ? { ...q, status: 'downloaded' } : q
          )
        )
      } catch (error) {
        setDownloadQueue(queue =>
          queue.map(q => (q.id === item.id ? { ...q, status: 'error' } : q))
        )
      }
    }

    setIsDownloading(false)
    Alert.alert('Download Complete', 'All works have been processed.')
  }

  const dynamicStyles = StyleSheet.create({
    container: {
      padding: 20,
      backgroundColor: darkMode ? '#121212' : '#f2f2f2',
      flex: 1
    },
    header: {
      fontSize: 24,
      fontWeight: 'bold',
      marginBottom: 10,
      color: darkMode ? '#ffffff' : '#000000'
    },
    instructions: {
      fontSize: 16,
      marginBottom: 10,
      color: darkMode ? '#e0e0e0' : '#333333'
    },
    inputContainer: {
      position: 'relative',
      marginBottom: 15
    },
    input: {
      borderWidth: 1,
      borderColor: darkMode ? '#444' : '#ccc',
      padding: 10,
      height: 120,
      textAlignVertical: 'top',
      backgroundColor: darkMode ? '#1e1e1e' : '#ffffff',
      color: darkMode ? '#ffffff' : '#000000'
    },
    clearButton: {
      position: 'absolute',
      right: 10,
      top: 10,
      backgroundColor: darkMode ? '#444' : '#ccc',
      padding: 5,
      borderRadius: 5
    },
    clearButtonText: {
      color: darkMode ? '#fff' : '#000',
      fontSize: 12,
      fontWeight: 'bold'
    },
    buttonContainer: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      marginBottom: 20
    },
    queueContainer: {
      marginTop: 20,
      backgroundColor: darkMode ? '#1e1e1e' : '#ffffff',
      padding: 10,
      borderRadius: 5
    },
    queueHeader: {
      fontSize: 18,
      fontWeight: 'bold',
      marginBottom: 10,
      color: darkMode ? '#ffffff' : '#000000'
    },
    queueItem: {
      flexDirection: 'row',
      alignItems: 'center',
      marginBottom: 10,
      backgroundColor: darkMode ? '#2a2a2a' : '#f9f9f9',
      padding: 10,
      borderRadius: 5
    },
    queueText: {
      flex: 1,
      color: darkMode ? '#ffffff' : '#000000'
    },
    statusText: {
      marginLeft: 10,
      fontWeight: 'bold',
      color: darkMode ? '#e0e0e0' : '#333333'
    },
    success: { color: 'green' },
    error: { color: 'red' },
    settingsButton: {
      alignSelf: 'flex-end',
      marginBottom: 15,
      padding: 10,
      backgroundColor: darkMode ? '#333' : '#ddd',
      borderRadius: 5
    },
    toggleText: {
      color: darkMode ? '#fff' : '#000',
      fontWeight: 'bold'
    }
  })

  return (
    <View style={dynamicStyles.container}>
      <TouchableOpacity
        style={dynamicStyles.settingsButton}
        onPress={toggleMode}
      >
        <Ionicons
          name={darkMode ? 'moon' : 'sunny'}
          size={24}
          color={darkMode ? '#fff' : '#000'}
        />
      </TouchableOpacity>
      <Text style={dynamicStyles.instructions}>made by: Mikaela Petra</Text>
      <Text style={dynamicStyles.instructions}>
        Paste one or multiple AO3 links below (links can be space- or
        line-separated):
      </Text>
      <View style={dynamicStyles.inputContainer}>
        <TextInput
          multiline
          style={dynamicStyles.input}
          value={links}
          onChangeText={handleLinksChange}
          placeholder='Enter AO3 links / id here... (e.g., https://archiveofourown.org/works/12345678 || 12345678 || https://archiveofourown.org/works/12345678/chapters/12345678)'
          placeholderTextColor={darkMode ? '#aaa' : '#666'}
        />
        {links.trim() !== '' && (
          <TouchableOpacity
            style={dynamicStyles.clearButton}
            onPress={handleClearInput}
          >
            <Text style={dynamicStyles.clearButtonText}>Clear</Text>
          </TouchableOpacity>
        )}
      </View>
      <View style={dynamicStyles.buttonContainer}>
        <Button
          title='Download'
          onPress={handleDownload}
          disabled={isDownloading}
        />
        <Button
          title='Go to Library'
          onPress={() => navigation.navigate('Library')}
        />
      </View>

      <ScrollView
        ref={scrollViewRef}
        contentContainerStyle={dynamicStyles.queueContainer}
      >
        <Text style={dynamicStyles.queueHeader}>Download Queue:</Text>
        {downloadQueue.map(item => (
          <View key={item.id} style={dynamicStyles.queueItem}>
            <Text style={dynamicStyles.queueText}>{item.link}</Text>
            <View style={{ flexDirection: 'row', alignItems: 'center' }}>
              {item.status === 'downloading' && (
                <ActivityIndicator size='small' color='#0000ff' />
              )}
              <Text
                style={[
                  dynamicStyles.statusText,
                  item.status === 'downloaded' && dynamicStyles.success,
                  item.status === 'error' && dynamicStyles.error
                ]}
              >
                {item.status.charAt(0).toUpperCase() + item.status.slice(1)}
              </Text>
            </View>
          </View>
        ))}
      </ScrollView>
    </View>
  )
}

export default HomeScreen
