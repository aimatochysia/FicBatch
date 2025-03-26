import React, { useEffect, useState } from 'react'
import {
  View,
  FlatList,
  Text,
  TouchableOpacity,
  Alert,
  Modal,
  StyleSheet,
  Switch
} from 'react-native'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { useNavigation } from '@react-navigation/native'
import * as FileSystem from 'expo-file-system'
import { Ionicons } from '@expo/vector-icons'

const LibraryScreen = () => {
  const [works, setWorks] = useState([])
  const [theme, setTheme] = useState('light')
  const [settingsVisible, setSettingsVisible] = useState(false)
  const [selectionMode, setSelectionMode] = useState(false)
  const [selectedWorks, setSelectedWorks] = useState([])
  const navigation = useNavigation()

  useEffect(() => {
    loadLibrary()
    loadTheme()
  }, [])

  const loadTheme = async () => {
    try {
      const storedTheme = await AsyncStorage.getItem('theme')
      if (storedTheme) {
        setTheme(storedTheme)
      }
    } catch (error) {
      console.error('❌ Error loading theme:', error)
    }
  }

  const toggleTheme = async () => {
    const newTheme = theme === 'light' ? 'dark' : 'light'
    setTheme(newTheme)
    try {
      await AsyncStorage.setItem('theme', newTheme)
    } catch (error) {
      console.error('❌ Error saving theme:', error)
    }
  }

  const loadLibrary = async () => {
    try {
      const storedWorks = await AsyncStorage.getItem('library')
      if (storedWorks) {
        const parsedWorks = JSON.parse(storedWorks)
          .map(work => ({
            ...work,
            filePath: work.filePath.replace('file://', '')
          }))
          .filter(
            (work, index, self) =>
              index === self.findIndex(w => w.filePath === work.filePath)
          )
        setWorks(parsedWorks)
      }
    } catch (error) {
      console.error('❌ Error loading library:', error)
    }
  }

  const refreshLibrary = () => {
    loadLibrary()
  }

  const deleteWork = async filePath => {
    try {
      await FileSystem.deleteAsync(filePath, { idempotent: true })
      const updatedWorks = works.filter(work => work.filePath !== filePath)
      setWorks(updatedWorks)
      await AsyncStorage.setItem('library', JSON.stringify(updatedWorks))
    } catch (error) {
      console.error('❌ Error deleting file:', error)
    }
  }

  const handleItemPress = item => {
    if (selectionMode) {
      if (selectedWorks.includes(item.filePath)) {
        const newSelection = selectedWorks.filter(
          path => path !== item.filePath
        )
        setSelectedWorks(newSelection)
        if (newSelection.length === 0) {
          setSelectionMode(false)
        }
      } else {
        setSelectedWorks([...selectedWorks, item.filePath])
      }
    } else {
      navigation.navigate('Reader', { filePath: item.filePath })
    }
  }

  const handleItemLongPress = item => {
    if (!selectionMode) {
      setSelectionMode(true)
      setSelectedWorks([item.filePath])
    }
  }

  const deleteSelectedWorks = () => {
    Alert.alert(
      'Delete Selected',
      'Are you sure you want to delete the selected works?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            for (const filePath of selectedWorks) {
              await deleteWork(filePath)
            }
            setSelectedWorks([])
            setSelectionMode(false)
          }
        }
      ]
    )
  }

  const styles = StyleSheet.create({
    container: {
      flex: 1,
      padding: 16,
      backgroundColor: theme === 'light' ? '#fff' : '#333'
    },
    itemContainer: {
      padding: 10,
      borderBottomWidth: 1,
      borderBottomColor: theme === 'light' ? '#ccc' : '#555',
      flexDirection: 'row',
      alignItems: 'center'
    },
    itemText: {
      flex: 1,
      color: theme === 'light' ? '#000' : '#fff'
    },
    selectedItem: {
      backgroundColor: theme === 'light' ? '#e0e0e0' : '#555'
    },
    floatingSettings: {
      position: 'absolute',
      top: 10,
      right: 10,
      zIndex: 1000,
      backgroundColor: theme === 'light' ? '#fff' : '#444',
      borderRadius: 20,
      padding: 10,
      elevation: 5
    },
    refreshButton: {
      alignSelf: 'center',
      marginTop: 10,
      paddingVertical: 10,
      borderTopWidth: 1,
      borderColor: theme === 'light' ? '#ccc' : '#555'
    },
    selectionHeader: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'space-between',
      paddingVertical: 10
    },
    trashButton: {
      padding: 10
    },
    settingsModalContainer: {
      flex: 1,
      backgroundColor: 'rgba(0,0,0,0.5)',
      justifyContent: 'center',
      alignItems: 'center'
    },
    settingsModalContent: {
      width: 250,
      backgroundColor: theme === 'light' ? '#fff' : '#444',
      padding: 20,
      borderRadius: 10,
      elevation: 10
    },
    settingsTitle: {
      fontSize: 18,
      fontWeight: 'bold',
      marginBottom: 10,
      color: theme === 'light' ? '#000' : '#fff'
    }
  })

  return (
    <View style={styles.container}>
      {selectionMode && (
        <View style={styles.selectionHeader}>
          <TouchableOpacity
            onPress={deleteSelectedWorks}
            style={styles.trashButton}
          >
            <Ionicons name='trash' size={24} color='red' />
          </TouchableOpacity>
          <Text style={{ color: theme === 'light' ? '#000' : '#fff' }}>
            {selectedWorks.length} Selected
          </Text>
        </View>
      )}

      <FlatList
        data={works}
        keyExtractor={item => item.filePath}
        renderItem={({ item }) => {
          const isSelected = selectedWorks.includes(item.filePath)
          return (
            <TouchableOpacity
              onPress={() => handleItemPress(item)}
              onLongPress={() => handleItemLongPress(item)}
              style={[styles.itemContainer, isSelected && styles.selectedItem]}
            >
              {selectionMode && (
                <View style={{ marginRight: 10 }}>
                  <View
                    style={{
                      height: 20,
                      width: 20,
                      borderRadius: 3,
                      borderWidth: 1,
                      borderColor: theme === 'light' ? '#000' : '#fff',
                      backgroundColor: isSelected ? 'red' : 'transparent'
                    }}
                  />
                </View>
              )}
              <Text style={styles.itemText}>{item.title}</Text>
            </TouchableOpacity>
          )
        }}
      />

      <TouchableOpacity style={styles.refreshButton} onPress={refreshLibrary}>
        <Text style={{ color: theme === 'light' ? '#000' : '#fff' }}>
          Refresh Library
        </Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={styles.floatingSettings}
        onPress={() => setSettingsVisible(true)}
      >
        <Text style={{ color: theme === 'light' ? '#000' : '#fff' }}>
          Settings
        </Text>
      </TouchableOpacity>

      <Modal
        visible={settingsVisible}
        transparent
        animationType='fade'
        onRequestClose={() => setSettingsVisible(false)}
      >
        <TouchableOpacity
          style={styles.settingsModalContainer}
          activeOpacity={1}
          onPressOut={() => setSettingsVisible(false)}
        >
          <View style={styles.settingsModalContent}>
            <Text style={styles.settingsTitle}>Settings</Text>
            <View
              style={{
                flexDirection: 'row',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}
            >
              <Text style={{ color: theme === 'light' ? '#000' : '#fff' }}>
                Dark Mode
              </Text>
              <Switch value={theme === 'dark'} onValueChange={toggleTheme} />
            </View>
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  )
}

export default LibraryScreen
