import React, { useState, useEffect } from 'react'
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

const HomeScreen = ({ navigation }) => {
  const [links, setLinks] = useState('')
  const [downloadQueue, setDownloadQueue] = useState([])
  const [isDownloading, setIsDownloading] = useState(false)
  const [darkMode, setDarkMode] = useState(false)

  // Load mode preference on mount.
  useEffect(() => {
    ;(async () => {
      const savedMode = await AsyncStorage.getItem('darkMode')
      if (savedMode !== null) {
        setDarkMode(savedMode === 'true')
      }
    })()
  }, [])

  // Toggle dark/light mode and persist it.
  const toggleMode = async () => {
    const newMode = !darkMode
    setDarkMode(newMode)
    await AsyncStorage.setItem('darkMode', newMode.toString())
  }

  // Parse input text into a list of link objects.
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

  const handleDownload = async () => {
    if (!links.trim()) {
      Alert.alert('Error', 'Enter at least one link.')
      return
    }

    // Reset statuses to pending and mark as downloading.
    const items = parseLinks(links)
    setDownloadQueue(items)
    setIsDownloading(true)

    // Process each link sequentially.
    for (const item of items) {
      // Update status to downloading.
      setDownloadQueue(queue =>
        queue.map(q => (q.id === item.id ? { ...q, status: 'downloading' } : q))
      )

      try {
        await downloadAO3Work(item.link)
        // Update status to downloaded.
        setDownloadQueue(queue =>
          queue.map(q =>
            q.id === item.id ? { ...q, status: 'downloaded' } : q
          )
        )
      } catch (error) {
        // Update status to error.
        setDownloadQueue(queue =>
          queue.map(q => (q.id === item.id ? { ...q, status: 'error' } : q))
        )
      }
    }

    setIsDownloading(false)
    Alert.alert('Download Complete', 'All works have been processed.')
  }

  // Dynamic styles based on dark mode.
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
    input: {
      borderWidth: 1,
      borderColor: darkMode ? '#444' : '#ccc',
      padding: 10,
      marginBottom: 15,
      height: 120,
      textAlignVertical: 'top',
      backgroundColor: darkMode ? '#1e1e1e' : '#ffffff',
      color: darkMode ? '#ffffff' : '#000000'
    },
    buttonContainer: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      marginBottom: 20
    },
    queueContainer: {
      marginTop: 20
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
      marginBottom: 10
    },
    queueText: {
      flex: 1,
      color: darkMode ? '#ffffff' : '#000000'
    },
    statusText: {
      marginLeft: 10,
      fontWeight: 'bold'
    },
    success: { color: 'green' },
    error: { color: 'red' },
    toggleButton: {
      marginBottom: 15,
      padding: 10,
      backgroundColor: darkMode ? '#333' : '#ddd',
      alignItems: 'center',
      borderRadius: 5
    },
    toggleText: {
      color: darkMode ? '#fff' : '#000',
      fontWeight: 'bold'
    }
  })

  return (
    <ScrollView contentContainerStyle={dynamicStyles.container}>
      <TouchableOpacity style={dynamicStyles.toggleButton} onPress={toggleMode}>
        <Text style={dynamicStyles.toggleText}>
          Switch to {darkMode ? 'Light' : 'Dark'} Mode
        </Text>
      </TouchableOpacity>
      {/*need to change!!!!❌❌❌ */}
      <Text style={dynamicStyles.header}>FicBatch</Text>
      <Text style={dynamicStyles.Text}>made by: Mikaela Petra</Text>
      <Text style={dynamicStyles.instructions}>
        Paste one or multiple AO3 links below (links can be space- or
        line-separated):
      </Text>
      <TextInput
        multiline
        style={dynamicStyles.input}
        value={links}
        onChangeText={handleLinksChange}
        placeholder='Enter AO3 links / id here... (e.g., https://archiveofourown.org/works/12345678 || 12345678 || https://archiveofourown.org/works/12345678/chapters/12345678)'
        placeholderTextColor={darkMode ? '#aaa' : '#666'}
      />
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

      <View style={dynamicStyles.queueContainer}>
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
      </View>
    </ScrollView>
  )
}

export default HomeScreen
