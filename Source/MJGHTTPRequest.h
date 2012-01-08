//
//  MJGHTTPRequest.h
//  MJGHTTPRequest
//
//  Copyright (c) 2011 Matt Galloway. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer. 
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Foundation/Foundation.h>

typedef enum {
    MJGHTTPRequestMethodGET = 1,
    MJGHTTPRequestMethodPOST,
} MJGHTTPRequestMethod;

typedef enum {
    MJGHTTPRequestMethodPOSTFormatRawData = 1,
    MJGHTTPRequestMethodPOSTFormatURLEncode,
    MJGHTTPRequestMethodPOSTFormatFormData,
} MJGHTTPRequestPOSTFormat;

typedef void(^MJGHTTPRequestHandler)(id result, NSHTTPURLResponse *response, NSError *error);
typedef void(^MJGHTTPRequestProgressHandler)(BOOL uploading, float progress);

@class MJGHTTPRequest;

@interface MJGHTTPRequest : NSObject

@property (nonatomic, strong) NSDictionary *parameters;
@property (nonatomic, assign) MJGHTTPRequestPOSTFormat postFormat;

- (id)initWithRequestMethod:(MJGHTTPRequestMethod)method;
+ (MJGHTTPRequest*)requestWithRequestMethod:(MJGHTTPRequestMethod)method;

- (void)setPOSTBody:(NSData*)data type:(NSString*)type;
- (void)addFileData:(NSData*)data forKey:(NSString*)key withFilename:(NSString*)filename type:(NSString*)type;

- (void)startWithHandler:(MJGHTTPRequestHandler)handler;
- (void)startWithHandler:(MJGHTTPRequestHandler)handler progressHandler:(MJGHTTPRequestProgressHandler)progressHandler;
- (void)cancel;

/**
 * IMPORTANT: Must override this method!
 * Return the URL to hit for this request.
 */
- (NSString*)url;

/**
 * Return any extra paramters to add to the request.
 */
- (NSDictionary*)extraParameters;

/**
 * Return any extra GET query paramters to add to the request.
 * This can be used to always have certain parameters in the query part of the URL.
 */
- (NSDictionary*)extraGetParameters;

/**
 * Optionally override this to handle the data which has been returned from the request.
 * If error is set by this method then it is passed back to the handler.
 * An example implementation for this would be to deserialise a JSON body.
 */
- (id)handleResult:(NSData*)result error:(NSError**)error;

@end
