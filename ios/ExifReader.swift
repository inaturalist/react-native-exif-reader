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
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
            let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
            if let dict = imageProperties as? [String: Any] {
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
        }

        return response
    }

    @objc(readExif:withResolver:withRejecter:)
    func readExif(uri: String, resolve:RCTPromiseResolveBlock,reject:RCTPromiseRejectBlock) -> Void {
        var response:Dictionary<String, Any>?

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
                        response = self.parseExif(data:unwrappedData)
                    }
                })
            } else {
                // Pre-iOS-13 way of retrieving image data
                imageManager.requestImageData(for: asset, options: options, resultHandler: {(data,string,imageOrientation, dictionary) in
                    if let unwrappedData = data {
                        response = self.parseExif(data:unwrappedData)
                    }
                })

            }
        }

        if (response != nil) {
            resolve(response)
        } else {
            reject("Error", "Couldn't parse EXIF for file", nil)
        }
    }
}
