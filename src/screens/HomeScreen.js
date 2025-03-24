import React, { useState } from 'react';
import { View, Text, TextInput, Button, ScrollView, Alert } from 'react-native';
import { downloadAO3Work } from '../utils/downloader';

const HomeScreen = ({ navigation }) => {
  const [links, setLinks] = useState('');
  
  const handleDownload = async () => {
    if (!links.trim()) {
      Alert.alert('Error', 'Enter at least one link.');
      return;
    }
    
    const linkArray = links.split(/\s+/);
    for (const link of linkArray) {
      await downloadAO3Work(link);
    }
    
    Alert.alert('Download Complete', 'All works have been downloaded.');
  };

  return (
    <ScrollView contentContainerStyle={{ padding: 20 }}>
      <Text>Enter AO3 links (one per line or space-separated):</Text>
      <TextInput
        multiline
        style={{ borderWidth: 1, padding: 10, marginTop: 10, height: 100 }}
        value={links}
        onChangeText={setLinks}
      />
      <Button title="Download" onPress={handleDownload} />
      <Button title="Go to Library" onPress={() => navigation.navigate('Library')} />
    </ScrollView>
  );
};

export default HomeScreen;
