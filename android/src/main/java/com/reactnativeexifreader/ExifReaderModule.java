package com.reactnativeexifreader;

import androidx.annotation.NonNull;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Arguments;
import android.util.Log;
import java.io.IOException;
import androidx.exifinterface.media.ExifInterface;
import com.drew.metadata.Directory;
import com.drew.metadata.Metadata;
import com.drew.metadata.exif.GpsDirectory;
import com.drew.lang.Rational;
import com.drew.imaging.ImageMetadataReader;
import com.drew.imaging.ImageProcessingException;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.TimeZone;
import java.sql.Timestamp;
import java.io.InputStream;
import java.util.Date;
import android.content.Context;
import android.net.Uri;
import java.util.Locale;
import java.text.DateFormat;

@ReactModule(name = ExifReaderModule.NAME)
public class ExifReaderModule extends ReactContextBaseJavaModule {
    public static final String NAME = "ExifReader";

    private Context mContext;

    public ExifReaderModule(ReactApplicationContext reactContext) {
        super(reactContext);
        mContext = reactContext;
    }

    @Override
    @NonNull
    public String getName() {
        return NAME;
    }

    @ReactMethod
    public void readExif(String uri, Promise promise) {
        Uri photoUri = Uri.parse(uri);
        WritableMap params = Arguments.createMap();

        try {
            InputStream is = mContext.getContentResolver().openInputStream(photoUri);

            double[] latLng = null;

            it.sephiroth.android.library.exif2.ExifInterface exif = null;

            try {
                exif = new it.sephiroth.android.library.exif2.ExifInterface();
                exif.readExif(is, it.sephiroth.android.library.exif2.ExifInterface.Options.OPTION_ALL);
            } catch (Exception exc) {
                Log.e(NAME, "Exception while reading EXIF data from file:", exc);
                exif = null;
            }

            ExifInterface orgExif = null;

            if (exif == null) {
                Log.e(NAME, "Could not read EXIF data from photo using Sephiroth library - trying built-in Android library");
            }

            is.close();
            is = mContext.getContentResolver().openInputStream(photoUri);
            orgExif = new ExifInterface(is);

            if (exif != null) {
                latLng = exif.getLatLongAsDoubles();
            }

            if (!areCoordsValid(latLng)) {
                Log.e(NAME, "importPhotoMetadata: Invalid lat/lng = " + (latLng != null ? latLng[0] + ":" + latLng[1] : "null") + ": trying regular EXIF library");

                latLng = orgExif.getLatLong();
            }

            if (areCoordsValid(latLng)) {
                Log.i(NAME, "importPhotoMetadata: Got lng/lat = " + latLng[0] + "/" + latLng[1]);
                params.putDouble("latitude", latLng[0]);
                params.putDouble("longitude", latLng[1]);

            } else {
                // No coordinates - don't override the observation coordinates
                Log.i(NAME, "No lat/lng: " + latLng);
            }

            try {
                // Read GPSHPositioningError EXIF NAME to get positional accuracy
                is.close();
                is = mContext.getContentResolver().openInputStream(photoUri);
                Metadata metadata = ImageMetadataReader.readMetadata(is);

                Directory directory = metadata.getFirstDirectoryOfType(GpsDirectory.class);
                if (directory != null) {
                    Rational value = directory.getRational(GpsDirectory.TAG_H_POSITIONING_ERROR);
                    if (value != null) {
                        // Round any accuracy less than 1 (but greater than zero) to 1
                        Float acc = value.floatValue();
                        params.putInt("positional_accuracy", acc > 0 & acc < 1 ? 1 : acc.intValue());
                    }
                }

            } catch (ImageProcessingException e) {
                Log.e(NAME, "ImageProcessingException", e);
            }


            String datetime = null;
            boolean useLocalTimezone = false;

            SimpleDateFormat exifDateFormat = new SimpleDateFormat("yyyy:MM:dd HH:mm:ss");

            if (exif != null) {
                // No timezone defined - assume user's local timezone
                useLocalTimezone = true;
                String dateTimeValue = exif.getTagStringValue(it.sephiroth.android.library.exif2.ExifInterface.TAG_DATE_TIME_ORIGINAL);
                datetime = dateTimeValue != null ? dateTimeValue.trim() : null;

                if (datetime == null) {
                    datetime = exif.getTagStringValue(it.sephiroth.android.library.exif2.ExifInterface.TAG_DATE_TIME);
                }
            }

            if ((exif == null) || (datetime == null)) {
                // Try using built-in EXIF library instead
                useLocalTimezone = true;
                datetime = orgExif.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL);

                if (datetime == null) {
                    datetime = orgExif.getAttribute(ExifInterface.TAG_DATETIME);
                }
            }

            if (datetime != null) {
                if (!useLocalTimezone) exifDateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));

                try {
                    Date date = exifDateFormat.parse(datetime);
                    Log.i(NAME, String.format("%s - %s", datetime, date));
                    Timestamp timestamp = new Timestamp(date.getTime());

                    DateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US);
                    dateFormat.setTimeZone(TimeZone.getTimeZone("UTC"));
                    params.putString("date", dateFormat.format(date));
                } catch (ParseException e) {
                    Log.e(NAME, "Failed to parse " + datetime + ": " + e);
                }
            } else {
                // No original datetime - nullify the date
                Log.e(NAME, "No datetime found");
            }

            is.close();
        } catch (IOException e) {
            Log.e(NAME, "couldn't find " + photoUri);
        }

        promise.resolve(params);
    }

     boolean areCoordsValid(double[] latLng) {
         return ((latLng != null) && (latLng.length >= 2) && (!Double.isNaN(latLng[0])) && (!Double.isNaN(latLng[1])));
     }

}
