import React from 'react'
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs'
import { createStackNavigator } from '@react-navigation/stack'
import { NavigationContainer } from '@react-navigation/native'
import { Ionicons } from '@expo/vector-icons'
import { View, Text } from 'react-native'

import HomeScreen from './screens/HomeScreen'
import LibraryScreen from './screens/LibraryScreen'
import ReaderScreen from './screens/ReaderScreen'

const Tab = createBottomTabNavigator()
const Stack = createStackNavigator()

const headerOptions = {
  headerStyle: { backgroundColor: '#222', height: 60 },
  headerTitleStyle: {
    color: 'white',
    fontSize: 16,
    textAlign: 'center'
  }
}

const HomeStack = () => (
  <Stack.Navigator screenOptions={headerOptions}>
    <Stack.Screen
      name='HomeMain'
      component={HomeScreen}
      options={{ title: 'FicBatch' }}
    />
  </Stack.Navigator>
)

const LibraryStack = () => (
  <Stack.Navigator screenOptions={headerOptions}>
    <Stack.Screen
      name='LibraryMain'
      component={LibraryScreen}
      options={{ title: 'Library' }}
    />
    <Stack.Screen
      name='Reader'
      component={ReaderScreen}
      options={({ route }) => ({ title: route.params?.title || 'Reader' })}
    />
  </Stack.Navigator>
)

const AppNavigator = () => (
  <NavigationContainer>
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarShowLabel: false,
        tabBarStyle: { backgroundColor: '#222', height: 40 },
        tabBarIcon: ({ color, size }) => {
          let iconName = route.name === 'Home' ? 'home-outline' : 'book-outline'
          return <Ionicons name={iconName} size={size} color={color} />
        }
      })}
    >
      <Tab.Screen name='Home' component={HomeStack} />
      <Tab.Screen name='Library' component={LibraryStack} />
    </Tab.Navigator>
  </NavigationContainer>
)

export default AppNavigator
