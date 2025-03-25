import React, { useEffect, useState, useRef } from 'react';
import { View, Text, TouchableOpacity, Modal, StyleSheet, Switch, ScrollView, Animated } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { WebView } from 'react-native-webview';
import * as FileSystem from 'expo-file-system';
import { Picker } from '@react-native-picker/picker';
import { Ionicons } from '@expo/vector-icons';

const SETTINGS_KEY = 'reader_settings';
const PROGRESS_KEY = 'reading_progress';

const ReaderScreen = ({ route }) => {
  const { filePath } = route.params;
  const [htmlContent, setHtmlContent] = useState('');
  const [modalVisible, setModalVisible] = useState(false);
  const [menuVisible, setMenuVisible] = useState(false);
  const [darkMode, setDarkMode] = useState(false);
  const [fontSize, setFontSize] = useState(16);
  const [fontFamily, setFontFamily] = useState('serif');
  const [textColor, setTextColor] = useState('#000');
  const [chapters, setChapters] = useState([]);
  const webViewRef = useRef(null);
  const slideAnim = useRef(new Animated.Value(-250)).current;

  useEffect(() => {
    const loadFile = async () => {
      try {
        const formattedPath = filePath.startsWith('file://') ? filePath : 'file://' + filePath;
        const fileContent = await FileSystem.readAsStringAsync(formattedPath, { encoding: FileSystem.EncodingType.UTF8 });
        setHtmlContent(fileContent);
        extractChapters(fileContent);
      } catch (error) {
        console.error(`❌ Error loading file: ${filePath}`, error);
      }
    };
    loadFile();
    loadSettings();
    loadProgress();
  }, [filePath]);

  useEffect(() => {
    const saveProgressInterval = setInterval(saveProgress, 300000);
    return () => clearInterval(saveProgressInterval);
  }, [htmlContent]);

  const extractChapters = (html) => {
    const regex = /<(h[1-4])(?:[^>]*)>(.*?)<\/\1>/gi;
    let foundChapters = [];
    let match;
    while ((match = regex.exec(html)) !== null) {
      const chapterId = `chapter-${foundChapters.length}`;
      foundChapters.push({ text: match[2], id: chapterId });
    }
    setChapters(foundChapters);
  };

  const loadSettings = async () => {
    const savedSettings = await AsyncStorage.getItem(SETTINGS_KEY);
    if (savedSettings) {
      const { darkMode, fontSize, fontFamily, textColor } = JSON.parse(savedSettings);
      setDarkMode(darkMode);
      setFontSize(fontSize);
      setFontFamily(fontFamily);
      setTextColor(textColor);
    }
  };

  const saveSettings = async () => {
    await AsyncStorage.setItem(SETTINGS_KEY, JSON.stringify({ darkMode, fontSize, fontFamily, textColor }));
  };

  const loadProgress = async () => {
    const savedProgress = await AsyncStorage.getItem(PROGRESS_KEY);
    if (savedProgress && webViewRef.current) {
      webViewRef.current.injectJavaScript(`window.scrollTo(0, ${savedProgress});`);
    }
  };

  const saveProgress = async () => {
    if (webViewRef.current) {
      webViewRef.current.injectJavaScript(`window.ReactNativeWebView.postMessage(document.documentElement.scrollTop);`);
    }
  };

  const handleMessage = (event) => {
    AsyncStorage.setItem(PROGRESS_KEY, event.nativeEvent.data);
  };

  const scrollToChapter = (chapterId) => {
    webViewRef.current.injectJavaScript(`
      const element = document.getElementById(${JSON.stringify(chapterId)});
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    `);
    toggleMenu();
  };

  const injectedCSS = `
    <style>
      body { background-color: ${darkMode ? '#121212' : '#fff'}; color: ${darkMode ? '#eee' : textColor}; }
      .userstuff { font-size: ${fontSize}px; font-family: ${fontFamily}; }
      h1, h2, h3, h4 {
        scroll-margin-top: 20px;
      }
    </style>
    <script>
      document.addEventListener("DOMContentLoaded", function() {
        const headings = document.querySelectorAll("h1, h2, h3, h4");
        headings.forEach((heading, index) => {
          heading.id = "chapter-" + index;
        });
      });
    </script>
  `;

  const toggleMenu = () => {
    Animated.timing(slideAnim, {
      toValue: menuVisible ? -250 : 0,
      duration: 300,
      useNativeDriver: true,
    }).start();
    setMenuVisible(!menuVisible);
  };

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
        <Ionicons name="menu" size={24} color="white" />
      </TouchableOpacity>

      <Animated.View style={[styles.menuContainer, { transform: [{ translateX: slideAnim }] }]}> 
        <ScrollView>
          {chapters.map((chapter, index) => (
            <TouchableOpacity key={index} onPress={() => scrollToChapter(chapter.id)}>
              <Text style={styles.chapterItem}>{chapter.text}</Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </Animated.View>

      <TouchableOpacity style={styles.floatingButton} onPress={() => setModalVisible(true)}>
        <Ionicons name="settings" size={24} color="white" />
      </TouchableOpacity>

      <Modal visible={modalVisible} transparent={true} animationType="slide">
        <View style={styles.modalContainer}>
          <Text style={{ fontSize: 18, fontWeight: 'bold' }}>Settings</Text>
          <Switch value={darkMode} onValueChange={(value) => setDarkMode(value)} />
          <Picker selectedValue={fontSize} onValueChange={(value) => setFontSize(value)}>
            <Picker.Item label="Small" value={14} />
            <Picker.Item label="Medium" value={16} />
            <Picker.Item label="Large" value={18} />
          </Picker>
          <TouchableOpacity onPress={() => { setModalVisible(false); saveSettings(); }}>
            <Text style={{ color: 'blue', marginTop: 20 }}>Close</Text>
          </TouchableOpacity>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  menuButton: { position: 'absolute', top: 40, left: 20, backgroundColor: '#007AFF', padding: 12, borderRadius: 30, elevation: 5 },
  menuContainer: { position: 'absolute', top: 0, left: 0, width: 250, height: '100%', backgroundColor: '#333', paddingTop: 50 },
  chapterItem: { color: 'white', padding: 10, borderBottomWidth: 1, borderBottomColor: '#555' },
  floatingButton: { position: 'absolute', top: 40, right: 20, backgroundColor: '#007AFF', padding: 12, borderRadius: 30, elevation: 5 },
  modalContainer: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: 'white', padding: 20 }
});

export default ReaderScreen;
