import * as FileSystem from 'expo-file-system'
import AsyncStorage from '@react-native-async-storage/async-storage'
import { decode } from 'html-entities'

export const downloadAO3Work = async input => {
  let workIdMatch = input.match(/works\/(\d+)/) || input.match(/^(\d+)$/)
  if (!workIdMatch) {
    console.error('❌ Invalid AO3 work URL or ID.')
    return
  }

  const workId = workIdMatch[1]
  const downloadUrl = `https://archiveofourown.org/downloads/${workId}/a.html?updated_at=1738557260`

  const fileName = `${workId}.html`
  const filePath = FileSystem.documentDirectory + fileName

  try {
    const response = await fetch(downloadUrl)
    if (!response.ok) throw new Error(`Failed to fetch: ${response.status}`)

    let htmlContent = await response.text()
    const titleMatch = htmlContent.match(/<title>(.*?)<\/title>/)
    const title = titleMatch ? decode(titleMatch[1]) : 'Unknown Title'
    const publisherMatch = htmlContent.match(
      /<div class="byline">\s*<a>(.*?)<\/a>/
    )
    const publisher = publisherMatch
      ? decode(publisherMatch[1])
      : 'Unknown Publisher'
    const tags = []
    const tagsSectionMatch = htmlContent.match(
      /<dl class="tags">([\s\S]*?)<\/dl>/
    )
    if (tagsSectionMatch) {
      const tagsSection = tagsSectionMatch[1]
      const tagMatches = [...tagsSection.matchAll(/<dd>.*?<a[^>]*>(.*?)<\/a>/g)]
      for (const match of tagMatches) {
        tags.push(decode(match[1]))
      }
    }

    const metadata = {}
    const metadataMatches = htmlContent.match(
      /<div id="preface">[\s\S]*?<div class="meta">[\s\S]*?<dl class="tags">([\s\S]*?)<\/dl>/
    )

    if (metadataMatches) {
      const metadataText = metadataMatches[1]
      const metadataEntries = [...metadataText.matchAll(/<dd>(.*?)<\/dd>/g)]

      metadataEntries.forEach(entry => {
        const parts = entry[1].split(':').map(p => p.trim())
        if (parts.length === 2) {
          const key = parts[0].toLowerCase().replace(/\s+/g, '_')
          metadata[key] = parts[1]
        }
      })
    }
    console.log('📌 Extracted Data:', { title, publisher, tags })

    htmlContent = htmlContent.replace(/<div id="preface">[\s\S]*?<\/div>/, '')

    const metadataSection = `
      <div id="metadata">
        <h1>${title}</h1>
        <h3>by ${publisher}</h3>
        <p><strong>Tags:</strong> ${tags.join(', ')}</p>
      </div>
    `
    htmlContent = metadataSection + htmlContent

    await FileSystem.writeAsStringAsync(filePath, htmlContent, {
      encoding: FileSystem.EncodingType.UTF8
    })
    const cleanFilePath = filePath.replace('file://', '')

    console.log(`✅ File saved at: ${cleanFilePath}`)

    const workData = {
      title,
      publisher,
      filePath: cleanFilePath,
      url: downloadUrl,
      tags,
      metadata
    }
    const storedWorks = JSON.parse(await AsyncStorage.getItem('library')) || []
    const updatedWorks = storedWorks.filter(
      work => work.filePath !== cleanFilePath
    )
    updatedWorks.push(workData)
    await AsyncStorage.setItem('library', JSON.stringify(updatedWorks))

    console.log('📚 Library updated:', updatedWorks)
    return cleanFilePath
  } catch (error) {
    console.error('❌ Download Error:', error)
  }
}
