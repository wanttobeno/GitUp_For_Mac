/*
 Copyright (c) 2015, Pierre-Olivier Latour
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * The name of Pierre-Olivier Latour may not be used to endorse
 or promote products derived from this software without specific
 prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL PIERRE-OLIVIER LATOUR BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <SystemConfiguration/SystemConfiguration.h>

#import "GARawTracker.h"

// See https://developers.google.com/analytics/devguides/collection/protocol/v1/

#define kAPIHostName @"ssl.google-analytics.com"
#define kAPIURL @"https://" kAPIHostName @"/collect"
#define kAPITimeOut 5.0

#define kClientIDUserDefaultsKey @"GARawTrackerClientID"

static inline NSString* _URLEscapeString(NSString* string) {
  return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, CFSTR(":@/?&=+"), kCFStringEncodingUTF8));
}

static NSString* _PayloadFromArguments(NSDictionary* arguments) {
  NSMutableString* payload = [NSMutableString string];
  for (NSString* key in arguments) {
    NSString* value = arguments[key];
    if (payload.length) {
      [payload appendString:@"&"];
    }
    [payload appendFormat:@"%@=%@", key, _URLEscapeString(value)];
  }
  return payload;
}

@interface GARawTracker () {
  SCNetworkReachabilityRef _reachability;
  NSString* _basePayload;
}
@end

@implementation GARawTracker

+ (GARawTracker*)sharedTracker {
  static GARawTracker* tracker = nil;
  static dispatch_once_t token = 0;
  dispatch_once(&token, ^{
    tracker = [[GARawTracker alloc] init];
  });
  return tracker;
}

- (id)init {
  if ((self = [super init])) {
    _reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [kAPIHostName UTF8String]);
  }
  return self;
}

- (void)startWithTrackingID:(NSString*)trackingID {
  NSString* clientID = [[NSUserDefaults standardUserDefaults] stringForKey:kClientIDUserDefaultsKey];
  if (clientID == nil) {
    clientID = [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:clientID forKey:kClientIDUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
  NSString* appID = [[NSBundle mainBundle] bundleIdentifier];
  NSString* appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  NSString* appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
  NSDictionary* arguments = @{
                              @"v": @"1",
                              @"tid": trackingID,
                              @"cid": clientID,
                              @"an": _URLEscapeString(appName),
                              @"av": appVersion,
                              @"aid": appID
                            };
  _basePayload = _PayloadFromArguments(arguments);
}

- (BOOL)canSendEvents {
  BOOL online = YES;
  SCNetworkConnectionFlags flags;
  if (SCNetworkReachabilityGetFlags(_reachability, &flags) && (!(flags & kSCNetworkReachabilityFlagsReachable) || (flags & kSCNetworkReachabilityFlagsConnectionRequired))) {
    online = NO;
  }
  return online;
}

// TODO: Should we override the default user agent?
- (void)_sendHitWithType:(NSString*)type arguments:(NSDictionary*)arguments queueTime:(NSTimeInterval)queueTime async:(BOOL)async completionBlock:(void (^)(BOOL success))block {
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kAPIURL]];
  [request setHTTPMethod:@"POST"];
  [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
  NSMutableString* payload = [NSMutableString stringWithString:_basePayload];
  [payload appendFormat:@"&t=%@", type];
  if (arguments.count) {
    [payload appendString:@"&"];
    [payload appendString:_PayloadFromArguments(arguments)];
  }
  if (queueTime > 0.0) {
    [payload appendFormat:@"&qt=%.0f", queueTime * 1000.0];
  }
  NSData* body = [payload dataUsingEncoding:NSUTF8StringEncoding];
  [request setHTTPBody:body];
  [request setValue:[[NSNumber numberWithUnsignedInteger:body.length] stringValue] forHTTPHeaderField:@"Content-Length"];
  [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
  [request setTimeoutInterval:kAPITimeOut];
  
  void (^completionBlock)(NSURLResponse*, NSData*, NSError*) = ^(NSURLResponse* response, NSData* data, NSError* error) {
    BOOL success = [(NSHTTPURLResponse*)response statusCode] == 200;
    if (success) {
#if DEBUG
      NSLog(@"GARawTracker sent hit '%@' to Google Analytics with arguments: %@", type, arguments);
#endif
    } else {
      NSLog(@"GARawTracker failed sending hit '%@' to Google Analytics (%i): %@", type, (int)[(NSHTTPURLResponse*)response statusCode], error);
    }
    if (block) {
      block(success);
    }
  };
  if (async) {
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:completionBlock];
  } else {
    NSError* error = nil;
    NSURLResponse* response = nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    completionBlock(response, data, error);
  }
}

- (void)sendHitWithType:(NSString*)type
              arguments:(NSDictionary*)arguments
        completionBlock:(void (^)(BOOL success))block {
  [self _sendHitWithType:type arguments:arguments queueTime:0.0 async:YES completionBlock:block];
}
@end

@implementation GARawTracker (Extensions)

- (void)sendScreenView:(NSString*)screenName
       completionBlock:(void (^)(BOOL success))block {
  NSMutableDictionary* arguments = [NSMutableDictionary dictionary];
  [arguments setObject:screenName forKey:@"cd"];
  [self sendHitWithType:@"screenview" arguments:arguments completionBlock:block];
}

- (void)sendEventWithCategory:(NSString*)category
                       action:(NSString*)action
                        label:(NSString*)label
                        value:(NSString*)value
              completionBlock:(void (^)(BOOL success))block {
  NSMutableDictionary* arguments = [NSMutableDictionary dictionary];
  [arguments setObject:category forKey:@"ec"];
  [arguments setObject:action forKey:@"ea"];
  [arguments setValue:label forKey:@"el"];
  [arguments setValue:value forKey:@"ev"];
  [self sendHitWithType:@"event" arguments:arguments completionBlock:block];
}

- (void)sendExceptionWithDescription:(NSString*)description
                             isFatal:(BOOL)isFatal
                     completionBlock:(void (^)(BOOL success))block {
  NSMutableDictionary* arguments = [NSMutableDictionary dictionary];
  [arguments setValue:description forKey:@"exd"];
  [arguments setObject:(isFatal ? @"1" : @"0") forKey:@"exf"];
  [self sendHitWithType:@"exception" arguments:arguments completionBlock:block];
}

@end
