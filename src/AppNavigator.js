import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { NavigationContainer } from '@react-navigation/native';
import { Ionicons } from '@expo/vector-icons';

import HomeScreen from './screens/HomeScreen';
import LibraryScreen from './screens/LibraryScreen';
import ReaderScreen from './screens/ReaderScreen';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

const LibraryStack = () => (
  <Stack.Navigator>
    <Stack.Screen name="LibraryMain" component={LibraryScreen} options={{ title: "Library" }} />
    <Stack.Screen name="Reader" component={ReaderScreen} options={{ title: "Reader" }} />
  </Stack.Navigator>
);

const AppNavigator = () => (
  <NavigationContainer>
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarShowLabel: false,
        tabBarStyle: { backgroundColor: '#222', height: 60 },
        tabBarIcon: ({ color, size }) => {
          let iconName;
          if (route.name === 'Home') iconName = 'home-outline';
          else if (route.name === 'Library') iconName = 'book-outline';
          return <Ionicons name={iconName} size={size} color={color} />;
        },
      })}
    >
      <Tab.Screen name="Home" component={HomeScreen} />
      <Tab.Screen name="Library" component={LibraryStack} />
    </Tab.Navigator>
  </NavigationContainer>
);

export default AppNavigator;
