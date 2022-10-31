#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(ExifReader, NSObject)

RCT_EXTERN_METHOD(readExif:(NSString*)uri
                 withResolver:(RCTPromiseResolveBlock)resolve
                 withRejecter:(RCTPromiseRejectBlock)reject)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

@end
