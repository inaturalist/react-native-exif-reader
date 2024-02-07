# react-native-exif-reader
React Native EXIF Reader - uses native code both for Android and iOS to read EXIF metadata. Note that at the moment this is only intended for use with iNaturalist.

## Installation

```sh
npm install inaturalist/react-native-exif-reader
```

## Usage

```js
import { readExif } from "react-native-exif-reader";

// URL is retrieved from `CameraRoll.getPhotos` - see `App.tsx` in the example app
const result = await readExif('url');
// Result is an object containing date, latitude, longitude and positional_accuracy (if exists).
```

# Developer setup

See https://github.com/inaturalist/iNaturalistReactNative/blob/main/CONTRIBUTING.md for an overview of best practiceses. You'll need a basic [React Native development environment](https://reactnative.dev/docs/environment-setup).

```zsh
git clone git@github.com:inaturalist/react-native-exif-reader.git
cd react-native-exif-reader
npm i
```

## Running the example app

```zsh
cd example
npm i
bundle
(cd ios && pod install)
npx react-native run-ios
```

To run on a device you may need to run the app via XCode.
