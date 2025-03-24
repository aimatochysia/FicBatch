import React, { useEffect, useState } from 'react';
import { View, FlatList, Text, TouchableOpacity, Alert } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useNavigation } from '@react-navigation/native';
import * as FileSystem from 'expo-file-system';

const LibraryScreen = () => {
  const [works, setWorks] = useState([]);
  const navigation = useNavigation();

  useEffect(() => {
    // const clearStorage = async () => {
    //     await AsyncStorage.removeItem('library');
    //     console.log('✅ Cleared old library data');
    //   };
    
    //   clearStorage();
      
    const loadLibrary = async () => {
        try {
          const storedWorks = await AsyncStorage.getItem('library');
          if (storedWorks) {
            const parsedWorks = JSON.parse(storedWorks)
              .map(work => ({
                ...work,
                filePath: work.filePath.replace('file://', '')
              }))
              .filter((work, index, self) => 
                index === self.findIndex((w) => w.filePath === work.filePath)
              );
      
            setWorks(parsedWorks);
          }
        } catch (error) {
          console.error('❌ Error loading library:', error);
        }
      };
      

    loadLibrary();
  }, []);

  const deleteWork = async (filePath) => {
    try {
      await FileSystem.deleteAsync(filePath, { idempotent: true });
      const updatedWorks = works.filter(work => work.filePath !== filePath);
      setWorks(updatedWorks);
      await AsyncStorage.setItem('library', JSON.stringify(updatedWorks));
    } catch (error) {
      console.error('❌ Error deleting file:', error);
    }
  };

  return (
    <View style={{ flex: 1, padding: 16 }}>
      <FlatList
        data={works}
        keyExtractor={(item) => item.filePath}
        renderItem={({ item }) => (
          <TouchableOpacity
            onPress={() => navigation.navigate('Reader', { filePath: item.filePath })}
            onLongPress={() => deleteWork(item.filePath)}
            style={{ padding: 10, borderBottomWidth: 1 }}
          >
            <Text>{item.title}</Text>
          </TouchableOpacity>
        )}
      />
    </View>
  );
};

export default LibraryScreen;
