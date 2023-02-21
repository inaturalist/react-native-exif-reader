import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-exif-reader' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const ExifReader = NativeModules.ExifReader
  ? NativeModules.ExifReader
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function readExif(uri: string): Promise<Record<string, any>> {
  return ExifReader.readExif(uri);
}


export function writeExif(uri: string, exifData: Record<string, any> ): Promise<Boolean> {
  return ExifReader.writeExif(uri, exifData);
}
