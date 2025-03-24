import * as FileSystem from 'expo-file-system';
import AsyncStorage from '@react-native-async-storage/async-storage';

export const downloadAO3Work = async (url) => {
  if (!url.startsWith('https://archiveofourown.org')) return;

  const fullUrl = url.includes('?view_full_work=true') ? url : url + '?view_full_work=true';

  const fileName = fullUrl.split('/').pop().replace(/[?&=]/g, '_') + '.html';
  const filePath = FileSystem.documentDirectory + fileName;

  try {
    const response = await fetch(fullUrl);
    const htmlContent = await response.text();

    await FileSystem.writeAsStringAsync(filePath, htmlContent, { encoding: FileSystem.EncodingType.UTF8 });

    const cleanFilePath = filePath.replace('file://', '');

    console.log(`✅ File saved at: ${cleanFilePath}`);

    const titleMatch = htmlContent.match(/<title>(.*?)<\/title>/);
    const title = titleMatch ? titleMatch[1] : 'Unknown Title';
    const workData = { title, filePath: cleanFilePath, url };
    const storedWorks = JSON.parse(await AsyncStorage.getItem('library')) || [];

    const updatedWorks = storedWorks.filter(work => work.filePath !== cleanFilePath);
    updatedWorks.push(workData);

    await AsyncStorage.setItem('library', JSON.stringify(updatedWorks));
    console.log('📚 Library updated:', updatedWorks);

    return cleanFilePath;
  } catch (error) {
    console.error('❌ Download Error:', error);
  }
};
