import Foundation
import UIKit
import Photos
import PhotosUI
import CoreImage

@objc(ExifReader)
class ExifReader: NSObject {
    // Parses EXIF from raw image data - returns dictionary of parsed EXIF
    func parseExif(data: Data) -> Dictionary<String, Any> {
        var response = Dictionary<String, Any>()

        readEXIFFromData(data: data) { dict in
            // still need to look for a taken date
            if let exif = dict["{Exif}"] as? [String: Any] {
                let df = DateFormatter()
                df.calendar = Calendar(identifier: .gregorian)
                df.dateFormat = "yyyy:MM:dd HH:mm:ss"

                // sometimes different fields are populated, based on how & where the
                // photo was digitized.
                var tzOffset: String? = nil
                if let tzOffsetExif = exif["OffsetTimeDigitized"] as? String {
                    tzOffset = tzOffsetExif
                } else if let tzOffsetExif = exif["OffsetTime"] as? String {
                    tzOffset = tzOffsetExif
                } else if let tzOffsetExif = exif["OffsetTimeOriginal"] as? String {
                    tzOffset = tzOffsetExif
                }

                if let tzOffset = tzOffset {
                    let tzDateFormatter = DateFormatter()
                    tzDateFormatter.dateFormat = "ZZZZZ"

                    if let tzDate = tzDateFormatter.date(from: tzOffset),
                       let gmtDate = tzDateFormatter.date(from: "+00:00")
                    {
                        var timeDiff: Double = 0
                        if tzOffset.hasPrefix("-") {
                            timeDiff = tzDate.timeIntervalSince(gmtDate) * -1
                        } else {
                            timeDiff = gmtDate.timeIntervalSince(tzDate)
                        }

                        if let tz = TimeZone(secondsFromGMT: Int(timeDiff)) {
                            df.timeZone = tz
                        }
                    }
                }


                if let takenDateExif = exif["DateTimeOriginal"] as? String,
                   let takenDate = df.date(from: takenDateExif)
                {
                    let formatter = DateFormatter()
                    formatter.calendar = Calendar(identifier: .gregorian)
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                    if let tz = TimeZone(secondsFromGMT: 0) {
                        formatter.timeZone = tz
                    }
                    response["date"] = formatter.string(from:takenDate)
                }

                if let gps = dict["{GPS}"] as? [String: Any] {
                    if let latitude = gps["Latitude"] as? NSNumber,
                       let longitude = gps["Longitude"] as? NSNumber,
                       let latitudeRef = gps["LatitudeRef"] as? String,
                       let longitudeRef = gps["LongitudeRef"] as? String {

                        if latitudeRef == "S" {
                            response["latitude"] = latitude.doubleValue * -1
                        } else {
                            response["latitude"] = latitude.doubleValue
                        }
                        if longitudeRef == "W" {
                            response["longitude"] = -1 * longitude.doubleValue
                        } else {
                            response["longitude"] = longitude.doubleValue
                        }
                    }
                    if let hpositioningError = gps["HPositioningError"] as? NSNumber {
                        response["positional_accuracy"] = hpositioningError.doubleValue
                    }
                }
            }
        }

        return response
    }

    // Reads raw image data into an EXIF dictionary
    func readEXIFFromData(data: Data, completion:@escaping ([String: Any])->()) {
        var response = Dictionary<String, Any>()
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
            if let dict = imageProperties as? [String: Any] {
                completion(dict)
            }
        }
    }

    func readRawDataOfFile(uri: String, completion:@escaping (PHAsset?, Data?)->()) {
        if uri.starts(with: "ph://") {
            // PH Asset
            return readRawPHAssetData(uri: uri, completion: completion)
        } else {
            // Local file URI
            do {
                if let fileUri = URL(string: uri) {
                    let data = try Data(contentsOf: fileUri)
                    completion(nil, data)
                }
            } catch let error {
                print(error.localizedDescription)
                print(error)
            }
        }
    }


    // Reads the raw image data of a PHAsset
    func readRawPHAssetData(uri: String, completion:@escaping (PHAsset, Data)->()) {
        // We receive a PHAsset URL

        // Retrieve local asset ID from full URL we receive from library (prefixed with "ph://")
        let assetLocalId = String(uri[uri.index(uri.startIndex, offsetBy: 5)...])

        // Load the PHAsset
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalId], options:PHFetchOptions())
        results.enumerateObjects { (asset, _, _) in

            // Read raw image data from PHAsset
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.resizeMode = PHImageRequestOptionsResizeMode.none

            // Parse EXIF from raw image data
            let imageManager = PHImageManager.default()

            if #available(iOS 13, *) {
                // iOS 13 and above
                imageManager.requestImageDataAndOrientation(for: asset, options: options, resultHandler: {(data,string,imageOrientation, dictionary) in
                    if let unwrappedData = data {
                        completion(asset, unwrappedData)
                    }
                })
            } else {
                // Pre-iOS-13 way of retrieving image data
                imageManager.requestImageData(for: asset, options: options, resultHandler: {(data,string,imageOrientation, dictionary) in
                    if let unwrappedData = data {
                        completion(asset, unwrappedData)
                    }
                })

            }
        }
    }

    @objc(writeLocation:withLocation:withResolver:withRejecter:)
    func writeLocation(uri: String, location: Dictionary<String, Any>, resolve:@escaping
        RCTPromiseResolveBlock,reject:@escaping RCTPromiseRejectBlock) -> Void {
        var response:Dictionary<String, Any>?

        // Update the PHAsset with the new photo data

        let options = PHContentEditingInputRequestOptions()

        // Prepare for editing
        readRawPHAssetData(uri: uri) { (asset, data) in
          asset.requestContentEditingInput(with: options, completionHandler: { input, info in
              guard let input = input
                  else { fatalError("can't get content editing input: \(info)") }

              // This handler gets called on the main thread; dispatch to a background queue for processing.
              DispatchQueue.global(qos: .userInitiated).async {

                  // Create content editing output, write the adjustment data.
                  let output = PHContentEditingOutput(contentEditingInput: input)

                  // When rendering is done, commit the edit to the Photos library.
                  PHPhotoLibrary.shared().performChanges({
                      let request = PHAssetChangeRequest(for: asset)


                      let clLocation:CLLocation;

                      if (location.index(forKey: "positional_accuracy") != nil) {
                          // Also save positional accuracy
                          clLocation = CLLocation(
                              coordinate: CLLocationCoordinate2D(
                                  latitude: (location["latitude"] as! Double),
                                  longitude: (location["longitude"] as! Double)),
                              altitude: -1,
                              horizontalAccuracy: (location["positional_accuracy"] as! Double),
                              verticalAccuracy: -1,
                              timestamp: Date.init())
                      } else {
                          // Just lat/lng
                          clLocation = CLLocation(
                              latitude: (location["latitude"] as! Double),
                              longitude: (location["longitude"] as! Double))
                      }

                      request.location = clLocation
                  }, completionHandler: { success, error in
                      if !success {
                          reject("Error", "Can't edit asset", error)
                      } else {
                          resolve(true)
                      }
                  })
              }
      })
    }
   }

    @objc(writeExif:withExifData:withResolver:withRejecter:)
    func writeExif(uri: String, exifData: Dictionary<String, Any>, resolve:@escaping RCTPromiseResolveBlock,reject:@escaping RCTPromiseRejectBlock) -> Void {
        var response:Dictionary<String, Any>?

        readRawPHAssetData(uri: uri) { (asset, data) in
            self.readEXIFFromData(data: data) { dict in
                var mutatedDict = dict

                mutatedDict[kCGImagePropertyExifDictionary as String] = exifData as [String: Any]

                // Create new photo data with the modified EXIF metadata
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let uniformTypeIdentifier = CGImageSourceGetType(source) else { return }
                let finalData = NSMutableData(data: data)
                guard let destination = CGImageDestinationCreateWithData(finalData, uniformTypeIdentifier, 1, nil) else { return }
                CGImageDestinationAddImageFromSource(destination, source, 0, mutatedDict as CFDictionary)
                guard CGImageDestinationFinalize(destination) else { return }

                do {
                   try PHPhotoLibrary.shared().performChangesAndWait {
                       let request = PHAssetCreationRequest.forAsset()
                       request.addResource(with: .photo, data: Data(referencing: finalData), options: nil)
                       request.creationDate = Date()
                       // Return URI of newly saved PHAsset
                       let newImageIdentifier = request.placeholderForCreatedAsset!.localIdentifier
                       resolve("ph://\(newImageIdentifier)")
                   }
                } catch {
                  reject("Error", "Couldn't save PHAsset", nil)
                }
            }
      }
   }


    @objc(readExif:withResolver:withRejecter:)
    func readExif(uri: String, resolve:RCTPromiseResolveBlock,reject:RCTPromiseRejectBlock) -> Void {
        var response:Dictionary<String, Any>?

        readRawDataOfFile(uri: uri) { (asset, data) in
            if let unwrappedData = data {
                response = self.parseExif(data: unwrappedData)
            } else {
                response = nil
            }
        }

        if (response != nil) {
            resolve(response)
        } else {
            reject("Error", "Couldn't parse EXIF for file", nil)
        }
    }
}
