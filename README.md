# directory:

<code>/FicBatch
├── /assets
│ ├── icon.png
│ ├── splash.png
├── /src
│ ├── /screens
│ │ ├── HomeScreen.js
│ │ ├── LibraryScreen.js
│ │ ├── ReaderScreen.js
│ ├── /utils
│ │ ├── downloader.js
│ ├── AppNavigator.js
├── App.js
├── package.json
├── app.json
App.js
index.js
</code>

## to start:

<code>npm install -g expo-cli
npm install
npx expo install
npx expo start -c

#build using:
npm install -g eas-cli

eas build:configure
eas build -p android || eas build || eas build --platform android --profile production
eas submit to submit to mobile stores
</code>

## app.json settings:

<code>need to update "version": x.x.x app version
need to increment "versionCode": x integer</code>
