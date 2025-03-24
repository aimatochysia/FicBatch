import React, { useEffect, useState } from 'react';
import { View, Text } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { WebView } from 'react-native-webview';
import * as FileSystem from 'expo-file-system';

const ReaderScreen = ({ route }) => {
  let { filePath } = route.params;
  const [htmlContent, setHtmlContent] = useState('');

  useEffect(() => {
    const loadFile = async () => {
      try {
        console.log(`📖 Attempting to read: ${filePath}`);
    
        const formattedPath = filePath.startsWith('file://') ? filePath : 'file://' + filePath;

    
        const fileContent = await FileSystem.readAsStringAsync(formattedPath, { encoding: FileSystem.EncodingType.UTF8 });
        setHtmlContent(fileContent);
        console.log('✅ File loaded successfully');
      } catch (error) {
        console.error(`❌ Error loading file: ${formattedPath}`, error);
      }
    };
    

    loadFile();
  }, [filePath]);

  return (
    <View style={{ flex: 1 }}>
      {htmlContent ? <WebView source={{ html: htmlContent }} /> : <Text>Loading...</Text>}
    </View>
  );
};

export default ReaderScreen;
