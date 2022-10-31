# react-native-exif-reader
React Native EXIF Reader - uses native code both for Android and iOS to read EXIF metadata
## Installation

```sh
npm install react-native-exif-reader
```

## Usage

```js
import { readExif } from "react-native-exif-reader";

// URL is retrieved from `CameraRoll.getPhotos` - see `App.tsx` in the example app
const result = await readExif('url');
// Result is an object containing date, latitude, longitude and positional_accuracy (if exists).
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
