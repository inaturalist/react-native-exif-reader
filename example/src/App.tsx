/* eslint-disable react-native/no-inline-styles */
import * as React from 'react';

import {
  StyleSheet,
  View,
  Text,
  Button,
  Platform,
  ScrollView,
  Image,
  TouchableOpacity,
  PermissionsAndroid,
} from 'react-native';
import { readExif, writeExif, writeLocation } from 'react-native-exif-reader';
import { CameraRoll } from '@react-native-camera-roll/camera-roll';
import { PERMISSIONS, request, RESULTS } from 'react-native-permissions';
import { Camera, useCameraDevices } from 'react-native-vision-camera';
import { useRef, useState, useEffect } from 'react';

type Photos = {
  image: {
    uri: string;
  };
  group_name: string;
};

export default function App() {
  const [result, setResult] = useState();
  const [photos, setPhotos] = useState<Photos[]>([]);
  const devices = useCameraDevices('wide-angle-camera');
  const device = devices.back;
  const camera = useRef<Camera>(null);

  useEffect(() => {
    Platform.OS === 'android'
      ? request(PERMISSIONS.ANDROID.CAMERA)
      : request(PERMISSIONS.IOS.CAMERA);
  }, []);

  const importPhoto = async (photo: { image: { uri: string } }) => {
    const imageUri = photo.image.uri;
    console.log('AAA imageUri', imageUri);

    const exif = await readExif(imageUri);
    setResult(exif);
  };

  const setPhotoLocation = async () => {
    if (!camera.current) return;
    const cameraPhoto = await camera.current.takePhoto({ flash: 'off' });
    const imageUri = await CameraRoll.save(cameraPhoto.path, {
      type: 'photo',
      album: 'Camera',
    });
    await writeLocation(imageUri, {
      latitude: 37.773972,
      longitude: -122.431297,
    });
  };

  const setPhotoExif = async () => {
    if (!camera.current) return;
    const cameraPhoto = await camera.current.takePhoto({ flash: 'off' });
    const imageUri = await CameraRoll.save(cameraPhoto.path, {
      type: 'photo',
      album: 'Camera',
    });
    // iOS has their own set of limited EXIF tags - see here: https://developer.apple.com/documentation/imageio/exif_dictionary_keys?language=objc
    const newExif =
      Platform.OS === 'ios'
        ? { LensModel: 'some lens model' }
        : { Copyright: 'some copyright' };
    const response = await writeExif(imageUri, newExif);
    console.log('writeExif Response', response);
  };

  const showImages = async () => {
    const permission =
      Platform.OS === 'ios'
        ? PERMISSIONS.IOS.PHOTO_LIBRARY
        : PERMISSIONS.ANDROID.READ_EXTERNAL_STORAGE;

    let permissionResult = await request(permission);

    if (permissionResult !== RESULTS.GRANTED) return;

    if (Platform.OS === 'android' && Platform.Version >= 29) {
      permissionResult = await request(
        PERMISSIONS.ANDROID.ACCESS_MEDIA_LOCATION
      );
      if (permissionResult !== RESULTS.GRANTED) return;
    }

    if (Platform.OS === 'android') {
      await PermissionsAndroid.request(PERMISSIONS.ANDROID.CAMERA);
    }

    const p = await CameraRoll.getPhotos({
      first: 30,
      groupTypes: 'All',
      assetType: 'Photos',
    });

    setPhotos(p.edges.map((x) => x.node));
  };

  return (
    <View style={styles.container}>
      {result && (
        <View style={{ marginBottom: 20, marginTop: 10 }}>
          <Text>Result:</Text>
          <Text>Date: {result.date}</Text>
          <Text>Latitude: {result.latitude}</Text>
          <Text>Longitude: {result.longitude}</Text>
          <Text>Positional Accuracy: {result.positional_accuracy}</Text>
          <Text>Timezone Offset: {result.timezone_offset}</Text>
        </View>
      )}
      <Button
        title="Take photo and set location EXIF"
        onPress={setPhotoLocation}
        onPress={showImages}
        style={{ zIndex: 9999 }}
      />
      <Button title="Take photo and set raw EXIF" onPress={setPhotoExif} />
      <Button title="Show Photos" onPress={showImages} />
      {device && (
        <Camera
          ref={camera}
          style={[StyleSheet.absoluteFill, { top: 140 }]}
          device={device}
          isActive={true}
          photo
          orientation={'portrait'}
        />
      )}
      <ScrollView style={{ marginTop: 10 }}>
        {photos.map((photo) => (
          <TouchableOpacity
            key={photo.image.uri}
            onPress={() => importPhoto(photo)}
            style={{ paddingBottom: 20 }}
          >
            <Text>{photo.group_name}:</Text>
            <Image
              source={{ uri: photo.image.uri }}
              style={{ height: 100, width: 100 }}
            />
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: 40,
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
