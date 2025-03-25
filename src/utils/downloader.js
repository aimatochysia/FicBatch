import * as FileSystem from 'expo-file-system';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { decode } from 'html-entities';

export const downloadAO3Work = async (input) => {
  let workIdMatch = input.match(/works\/(\d+)/) || input.match(/^(\d+)$/);
  if (!workIdMatch) {
    console.error("❌ Invalid AO3 work URL or ID.");
    return;
  }

  const workId = workIdMatch[1];
  const downloadUrl = `https://archiveofourown.org/downloads/${workId}/a.html?updated_at=1738557260`;

  const fileName = `${workId}.html`;
  const filePath = FileSystem.documentDirectory + fileName;

  try {
    const response = await fetch(downloadUrl);
    if (!response.ok) throw new Error(`Failed to fetch: ${response.status}`);

    let htmlContent = await response.text();

    htmlContent = htmlContent.replace(/<div id="preface">[\s\S]*?<\/div>/, '');
    await FileSystem.writeAsStringAsync(filePath, htmlContent, { encoding: FileSystem.EncodingType.UTF8 });
    const cleanFilePath = filePath.replace('file://', '');
    console.log(`✅ File saved at: ${cleanFilePath}`);
    const titleMatch = htmlContent.match(/<title>(.*?)<\/title>/);
    const title = titleMatch ? decode(titleMatch[1]) : 'Unknown Title';

    const tags = [];
    const tagsSectionMatch = htmlContent.match(/<dl class="tags">([\s\S]*?)<\/dl>/);
    if (tagsSectionMatch) {
      const tagsSection = tagsSectionMatch[1];
      const tagMatches = [...tagsSection.matchAll(/<dd>.*?<a[^>]*>(.*?)<\/a>/g)];
      for (const match of tagMatches) {
        tags.push(decode(match[1]));
      }
    }

    const stats = {};
    const statsMatch = htmlContent.match(/<dt>Stats:<\/dt>\s*<dd>([\s\S]*?)<\/dd>/);
    if (statsMatch) {
      const statsContent = statsMatch[1];

      const publishedMatch = statsContent.match(/Published:\s*([\d-]+)/);
      if (publishedMatch) stats.publishedAt = publishedMatch[1];

      const completedMatch = statsContent.match(/Completed:\s*([\d-]+)/);
      if (completedMatch) stats.completedAt = completedMatch[1];

      const wordCountMatch = statsContent.match(/Words:\s*([\d,]+)/);
      if (wordCountMatch) stats.wordCount = parseInt(wordCountMatch[1].replace(/,/g, ''), 10);

      const chaptersMatch = statsContent.match(/Chapters:\s*([\d]+)\/([\d]+|\?)/);
      if (chaptersMatch) {
        stats.chapters = {
          current: parseInt(chaptersMatch[1], 10),
          total: chaptersMatch[2] === '?' ? 'Unknown' : parseInt(chaptersMatch[2], 10),
        };
      }
    }

    const workData = { title, filePath: cleanFilePath, url: downloadUrl, tags, stats };
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
