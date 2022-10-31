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
} from 'react-native';
import { readExif } from 'react-native-exif-reader';
import { CameraRoll } from '@react-native-camera-roll/camera-roll';
import { PERMISSIONS, request, RESULTS } from 'react-native-permissions';

export default function App() {
  const [result, setResult] = React.useState();
  const [photos, setPhotos] = React.useState([]);

  const importPhoto = async (photo) => {
    const imageUri = photo.image.uri;
    const exif = await readExif(imageUri);
    console.log('AAA RES', exif);
    setResult(exif);
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
        </View>
      )}
      <Button title="Show Photos" onPress={showImages} />
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
    paddingTop: 20,
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
