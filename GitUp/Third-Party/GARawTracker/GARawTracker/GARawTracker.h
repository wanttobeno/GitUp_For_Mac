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

#import <Foundation/Foundation.h>

#define GARAWTRACKER_TRACK_EVENT(__CATEGORY__, __ACTION__) [[GARawTracker sharedTracker] sendEventWithCategory:(__CATEGORY__) action:(__ACTION__) label:nil value:nil completionBlock:NULL]

@interface GARawTracker : NSObject
+ (GARawTracker*)sharedTracker;

- (void)startWithTrackingID:(NSString*)trackingID;  // Call from -applicationDidFinishLaunching:

- (BOOL)canSendEvents;  // Check if online

- (void)sendHitWithType:(NSString*)type
              arguments:(NSDictionary*)arguments  // May be nil
        completionBlock:(void (^)(BOOL success))block;  // May be NULL
@end

@interface GARawTracker (Extensions)
- (void)sendScreenView:(NSString*)screenName
       completionBlock:(void (^)(BOOL success))block;

- (void)sendEventWithCategory:(NSString*)category
                       action:(NSString*)action
                        label:(NSString*)label  // May be nil
                        value:(NSString*)value  // May be nil
              completionBlock:(void (^)(BOOL success))block;

- (void)sendExceptionWithDescription:(NSString*)description  // May be nil
                             isFatal:(BOOL)isFatal
                     completionBlock:(void (^)(BOOL success))block;
@end
