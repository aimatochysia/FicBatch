import React, { useEffect, useState } from 'react'
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  Modal,
  Switch,
  ScrollView,
  StyleSheet,
  Alert
} from 'react-native'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { Ionicons } from '@expo/vector-icons'
import { useNavigation } from '@react-navigation/native'
import * as FileSystem from 'expo-file-system'
const LibraryScreen = () => {
  const [works, setWorks] = useState([])
  const [searchQuery, setSearchQuery] = useState('')
  const [tagSearchQuery, setTagSearchQuery] = useState('')
  const [selectedTags, setSelectedTags] = useState([])
  const [tagCounts, setTagCounts] = useState({})
  const [sortBy, setSortBy] = useState('date')
  const [isTagModalVisible, setTagModalVisible] = useState(false)
  const [settingsVisible, setSettingsVisible] = useState(false)
  const [selectionMode, setSelectionMode] = useState(false)
  const [selectedWorks, setSelectedWorks] = useState([])
  const [theme, setTheme] = useState('dark')
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
        setWorks(parsedWorks)
        countTags(parsedWorks)
      }
    } catch (error) {
      console.error('❌ Error loading library:', error)
    }
  }

  const saveLibrary = async updatedWorks => {
    try {
      await AsyncStorage.setItem('library', JSON.stringify(updatedWorks))
    } catch (error) {
      console.error('❌ Error saving library:', error)
    }
  }

  const countTags = works => {
    const tagMap = {}
    works.forEach(work => {
      work.tags.forEach(tag => {
        tagMap[tag] = (tagMap[tag] || 0) + 1
      })
    })
    setTagCounts(tagMap)
  }

  const filteredWorks = works
    .filter(work =>
      work.title.toLowerCase().includes(searchQuery.toLowerCase())
    )
    .filter(work => selectedTags.every(tag => work.tags.includes(tag)))

  const sortedWorks = [...filteredWorks].sort((a, b) => {
    if (sortBy === 'alphabet') return a.title.localeCompare(b.title)
    if (sortBy === 'date')
      return new Date(b.dateCreated) - new Date(a.dateCreated)
    return 0
  })

  const toggleTagSelection = tag => {
    setSelectedTags(prev =>
      prev.includes(tag) ? prev.filter(t => t !== tag) : [...prev, tag]
    )
  }
  const deleteWork = async filePath => {
    try {
      await FileSystem.deleteAsync(filePath, { idempotent: true })
      setWorks(prev => prev.filter(work => work.filePath !== filePath))
      countTags(works.filter(work => work.filePath !== filePath))
    } catch (error) {
      console.error('❌ Error deleting file:', error)
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
            loadLibrary()
          }
        }
      ]
    )
  }

  const toggleSelectionMode = () => {
    setSelectionMode(!selectionMode)
    if (selectionMode) setSelectedWorks([])
  }

  const toggleWorkSelection = filePath => {
    setSelectedWorks(prev =>
      prev.includes(filePath)
        ? prev.filter(path => path !== filePath)
        : [...prev, filePath]
    )
  }

  const toggleFavorite = filePath => {
    const updatedWorks = works.map(work =>
      work.filePath === filePath
        ? { ...work, isFavorite: !work.isFavorite }
        : work
    )
    setWorks(updatedWorks)
    saveLibrary(updatedWorks)
  }

  return (
    <View
      style={[
        styles.container,
        { backgroundColor: theme === 'light' ? '#fff' : '#222' }
      ]}
    >
      <View style={styles.searchContainer}>
        <TextInput
          style={[
            styles.searchInput,
            { backgroundColor: theme === 'light' ? '#ddd' : '#444' },
            { color: theme === 'light' ? '#000' : '#fff' }
          ]}
          placeholder='Search by title...'
          placeholderTextColor={theme === 'light' ? '#888' : '#ccc'}
          value={searchQuery}
          onChangeText={setSearchQuery}
        />
        <TouchableOpacity
          onPress={() => setTagModalVisible(true)}
          style={[
            styles.filterButton,
            { backgroundColor: theme === 'light' ? '#ddd' : '#444' }
          ]}
        >
          <Ionicons
            name='filter-outline'
            size={18}
            color={theme === 'light' ? '#000' : '#fff'}
          />
        </TouchableOpacity>
      </View>
      <View style={styles.buttonsRow}>
        <TouchableOpacity
          onPress={toggleTheme}
          style={[
            styles.settingsButton,
            { backgroundColor: theme === 'light' ? '#ddd' : '#444' }
          ]}
        >
          <Ionicons
            name={theme === 'dark' ? 'moon' : 'sunny'}
            size={18}
            color={theme === 'light' ? '#000' : '#fff'}
          />
        </TouchableOpacity>
        <TouchableOpacity
          onPress={toggleSelectionMode}
          style={[
            styles.selectButton,
            { backgroundColor: theme === 'light' ? '#ddd' : '#444' }
          ]}
        >
          <Ionicons
            name='trash'
            size={18}
            color={
              selectionMode ? '#56CCF2' : theme === 'light' ? '#000' : '#fff'
            }
          />
        </TouchableOpacity>
        <TouchableOpacity
          onPress={loadLibrary}
          style={[
            styles.refreshButton,
            { backgroundColor: theme === 'light' ? '#ddd' : '#444' }
          ]}
        >
          <Ionicons
            name='refresh'
            size={18}
            color={theme === 'light' ? '#000' : '#fff'}
          />
        </TouchableOpacity>
      </View>

      <View style={styles.sortContainer}>
        <TouchableOpacity onPress={() => setSortBy('date')}>
          <Text
            style={[
              styles.sortText,
              sortBy === 'date' && styles.selectedSort,
              { color: theme === 'light' ? '#000' : '#aaa' }
            ]}
          >
            Date Created
          </Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={() => setSortBy('alphabet')}>
          <Text
            style={[
              styles.sortText,
              sortBy === 'alphabet' && styles.selectedSort,
              { color: theme === 'light' ? '#000' : '#aaa' }
            ]}
          >
            Alphabetical
          </Text>
        </TouchableOpacity>
      </View>

      {selectionMode && selectedWorks.length > 0 && (
        <TouchableOpacity
          style={styles.trashButton}
          onPress={deleteSelectedWorks}
        >
          <Ionicons name='trash' size={38} color='red' />
        </TouchableOpacity>
      )}

      <FlatList
        data={sortedWorks}
        keyExtractor={item => item.filePath}
        renderItem={({ item }) => (
          <View style={styles.itemContainer}>
            <TouchableOpacity
              style={styles.itemContent}
              onPress={() =>
                selectionMode
                  ? toggleWorkSelection(item.filePath)
                  : navigation.navigate('Reader', { filePath: item.filePath })
              }
            >
              <View style={styles.inlineContainer}>
                {selectionMode && (
                  <Ionicons
                    name={
                      selectedWorks.includes(item.filePath)
                        ? 'checkbox'
                        : 'square-outline'
                    }
                    size={20}
                    color={theme === 'light' ? '#000' : '#fff'}
                    style={styles.checkbox}
                  />
                )}
                <Text
                  style={[
                    styles.itemText,
                    { color: theme === 'light' ? '#000' : '#fff' }
                  ]}
                >
                  {item.title}
                </Text>
              </View>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={() => toggleFavorite(item.filePath)}
              style={styles.favoriteButton}
            >
              <Ionicons
                name={item.isFavorite ? 'star' : 'star-outline'}
                size={20}
                color={
                  item.isFavorite
                    ? 'yellow'
                    : theme === 'light'
                    ? '#000'
                    : '#fff'
                }
              />
            </TouchableOpacity>
          </View>
        )}
      />

      <Modal visible={settingsVisible} transparent animationType='slide'>
        <View style={styles.modalContainer}>
          <View style={styles.modalContent}>
            <Text
              style={[
                styles.modalTitle,
                { color: theme === 'light' ? '#000' : '#fff' }
              ]}
            >
              Settings
            </Text>
            <View style={styles.switchContainer}>
              <Text
                style={[
                  styles.switchLabel,
                  { color: theme === 'light' ? '#000' : '#fff' }
                ]}
              >
                Dark Mode
              </Text>
              <Switch
                value={theme === 'dark'}
                onValueChange={toggleTheme}
                thumbColor={theme === 'dark' ? '#fff' : '#000'}
              />
            </View>
            <TouchableOpacity
              style={styles.closeButton}
              onPress={() => setSettingsVisible(false)}
            >
              <Text
                style={[
                  styles.closeButtonText,
                  { color: theme === 'light' ? '#000' : '#fff' }
                ]}
              >
                Close
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <Modal visible={isTagModalVisible} transparent animationType='slide'>
        <View style={styles.modalContainer}>
          <View
            style={[
              styles.modalContent,
              { backgroundColor: theme === 'light' ? '#fff' : '#000' }
            ]}
          >
            <Text
              style={[
                styles.modalTitle,
                { color: theme === 'light' ? '#000' : '#fff' }
              ]}
            >
              Filter by Tags
            </Text>

            <TextInput
              style={[
                styles.tagSearchInput,
                { backgroundColor: theme === 'light' ? '#ddd' : '#444' }
              ]}
              placeholder='Search tags...'
              placeholderTextColor={theme === 'light' ? '#888' : '#ccc'}
              value={tagSearchQuery}
              onChangeText={setTagSearchQuery}
              color={theme === 'light' ? '#000' : '#fff'}
            />

            <ScrollView style={styles.tagList}>
              {Object.entries(tagCounts)
                .filter(([tag]) =>
                  tag.toLowerCase().includes(tagSearchQuery.toLowerCase())
                )
                .map(([tag, count]) => (
                  <TouchableOpacity
                    key={tag}
                    style={[
                      styles.tagItem,
                      selectedTags.includes(tag) && styles.selectedTag
                    ]}
                    onPress={() => toggleTagSelection(tag)}
                  >
                    <Text
                      style={[
                        styles.tagText,
                        { color: theme === 'light' ? '#000' : '#fff' }
                      ]}
                    >
                      {tag} ({count})
                    </Text>
                  </TouchableOpacity>
                ))}
            </ScrollView>

            <TouchableOpacity
              style={[
                styles.closeButton,
                { backgroundColor: theme === 'light' ? '#ddd' : '#444' }
              ]}
              onPress={() => setTagModalVisible(false)}
            >
              <Text
                style={[
                  styles.closeButtonText,
                  { color: theme === 'light' ? '#000' : '#fff' }
                ]}
              >
                Close
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  )
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16, backgroundColor: '#222' },
  searchContainer: {
    flexDirection: 'row',
    marginBottom: 10,
    justifyContent: 'space-between',
    alignItems: 'center'
  },
  buttonsRow: {
    flexDirection: 'row',
    marginBottom: 10,
    alignItems: 'center'
  },
  searchInput: {
    flex: 1,
    backgroundColor: '#444',
    color: '#fff',
    padding: 10,
    borderRadius: 8
  },
  filterButton: {
    marginLeft: 10,
    backgroundColor: '#555',
    padding: 10,
    borderRadius: 8
  },
  sortContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: 10
  },
  sortText: { color: '#aaa', fontSize: 16 },
  selectedSort: { color: '#fff', fontWeight: 'bold' },
  itemContainer: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    padding: 15,
    borderBottomWidth: 1,
    borderBottomColor: '#555'
  },
  itemContent: {
    flex: 1
  },
  itemText: {
    color: '#fff',
    fontSize: 16,
    flexWrap: 'wrap'
  },
  modalContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.5)'
  },
  modalContent: {
    width: 300,
    backgroundColor: '#333',
    padding: 20,
    borderRadius: 10
  },
  modalTitle: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 10
  },
  tagSearchInput: {
    backgroundColor: '#444',
    color: '#fff',
    padding: 8,
    borderRadius: 8,
    marginBottom: 10
  },
  tagList: { maxHeight: 300 },
  tagItem: { padding: 10, borderBottomWidth: 1, borderBottomColor: '#444' },
  selectedTag: { backgroundColor: '#555' },
  tagText: { color: '#fff' },
  closeButton: {
    marginTop: 10,
    backgroundColor: '#444',
    padding: 10,
    borderRadius: 5,
    alignItems: 'center'
  },
  refreshButtonContainer: {
    position: 'absolute',
    top: 550,
    right: 20,
    zIndex: 10
  },
  settingsButton: {
    marginLeft: 10,
    backgroundColor: '#555',
    padding: 10,
    borderRadius: 8
  },
  closeButtonText: { color: '#fff', fontSize: 16 },
  selectButton: {
    marginLeft: 10,
    backgroundColor: '#555',
    padding: 10,
    borderRadius: 8
  },
  trashButton: {
    position: 'absolute',
    bottom: 20,
    left: 20,
    backgroundColor: '#444',
    padding: 10,
    borderRadius: 8,
    zIndex: 10
  },
  checkbox: {
    marginRight: 10
  },
  inlineContainer: {
    flexDirection: 'row',
    alignItems: 'center'
  },
  switchContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginVertical: 10
  },
  switchLabel: {
    color: '#fff',
    fontSize: 16
  },
  refreshButton: {
    marginLeft: 10,
    backgroundColor: '#555',
    padding: 10,
    borderRadius: 8
  },
  favoriteButton: {
    marginLeft: 10,
    padding: 5
  }
})

export default LibraryScreen
