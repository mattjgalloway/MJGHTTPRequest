//
//  MJGHTTPRequest.m
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

#import "MJGHTTPRequest.h"

#import "NSDictionary-HTTP.h"

@interface MJGHTTPRequest ()
@property (nonatomic, unsafe_unretained) MJGHTTPRequestMethod method;
@property (nonatomic, strong) NSData *rawPostData;
@property (nonatomic, copy) NSString *rawPostType;
@property (nonatomic, strong) NSMutableArray *fileData;

@property (nonatomic, copy) MJGHTTPRequestHandler handler;
@property (nonatomic, copy) MJGHTTPProgressHandler progressHandler;

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, unsafe_unretained) long long expectedContentLength;
@property (nonatomic, unsafe_unretained) long long downloadedLength;

- (void)failWithError:(NSError*)error;
- (void)handleResponseData;

- (void)generateFormDataPostBody:(NSMutableURLRequest*)request;
- (void)generateUrlEncodedPostBody:(NSMutableURLRequest*)request;
@end

@implementation MJGHTTPRequest

@synthesize parameters, postFormat;
@synthesize method, rawPostData, rawPostType, fileData;
@synthesize handler, progressHandler;
@synthesize connection, response, responseData, expectedContentLength, downloadedLength;

#pragma mark -

- (id)initWithRequestMethod:(MJGHTTPRequestMethod)inMethod {
    if ((self = [self init])) {
        method = inMethod;
        postFormat = MJGHTTPRequestMethodPOSTFormatURLEncode;
    }
    return self;
}

+ (MJGHTTPRequest*)requestWithRequestMethod:(MJGHTTPRequestMethod)method {
    return [[MJGHTTPRequest alloc] initWithRequestMethod:method];
}


#pragma mark -

- (void)setPOSTBody:(NSData*)data type:(NSString*)type {
    // We need to set the post method to raw data if we're setting the post body
    postFormat = MJGHTTPRequestMethodPOSTFormatRawData;
    self.rawPostData = data;
    self.rawPostType = type;
}

- (void)addFileData:(NSData*)data forKey:(NSString*)key withFilename:(NSString*)filename type:(NSString*)type {
    // We need to set the post method to form data if we're adding files
    postFormat = MJGHTTPRequestMethodPOSTFormatFormData;
    
    NSDictionary *newFileData = [NSDictionary dictionaryWithObjectsAndKeys:
                                 data, @"data",
                                 key, @"key",
                                 filename, @"filename",
                                 type, @"type",
                                 nil];
    [fileData addObject:newFileData];
}

- (void)startWithHandler:(MJGHTTPRequestHandler)inHandler {
    [self startWithHandler:inHandler progressHandler:nil];
}

- (void)startWithHandler:(MJGHTTPRequestHandler)inHandler progressHandler:(MJGHTTPProgressHandler)inProgressHandler {
    self.handler = inHandler;
    self.progressHandler = inProgressHandler;
    
    NSMutableString *url = [NSMutableString stringWithString:[self url]];
    
    NSMutableDictionary *allGetParameters = [NSMutableDictionary dictionaryWithCapacity:0];
    [allGetParameters addEntriesFromDictionary:[self extraGetParameters]];
    
    if (method == MJGHTTPRequestMethodGET) {
        [allGetParameters addEntriesFromDictionary:[self extraParameters]];
        [allGetParameters addEntriesFromDictionary:self.parameters];
    }
    
    if (allGetParameters.count > 0) {
        [url appendFormat:@"?%@", [allGetParameters getQuery]];
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                            timeoutInterval:30.0];
    
    if (method == MJGHTTPRequestMethodGET) {
        [request setHTTPMethod:@"GET"];
    } else if (method == MJGHTTPRequestMethodPOST) {
        [request setHTTPMethod:@"POST"];
        if (postFormat == MJGHTTPRequestMethodPOSTFormatRawData) {
            [request setHTTPBody:rawPostData];
            if (rawPostType) {
                [request setValue:rawPostType forHTTPHeaderField:@"Content-Type"];
            }
        } else if (postFormat == MJGHTTPRequestMethodPOSTFormatFormData) {
            [self generateFormDataPostBody:request];
        } else if (postFormat == MJGHTTPRequestMethodPOSTFormatURLEncode) {
            [self generateUrlEncodedPostBody:request];
        }
    }
    
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)cancel {
    [connection cancel];
    connection = nil;
}


#pragma mark -

- (void)failWithError:(NSError*)error {
    if (self.handler) {
        self.handler(nil, self.response, error);
    }
}

- (void)handleResponseData {
    NSError *error = nil;
    id result = [self handleResult:responseData error:&error];
    if (self.handler) {
        self.handler(result, self.response, error);
    }
    responseData = nil;
}


#pragma mark - POST body generation

- (void)generateFormDataPostBody:(NSMutableURLRequest*)request {
    NSString *httpBoundary = @"----MJGHTTPRequest0xce86d7d02a229acfaca4b63f01a1171b";
    
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", httpBoundary] forHTTPHeaderField:@"Content-Type"];
    
    NSMutableData *body = [[NSMutableData alloc] init];
    
    NSString *startLine = [NSString stringWithFormat:@"\r\n"];
    NSString *endLine = [NSString stringWithFormat:@"\r\n--%@", httpBoundary];
    
    [body appendData:[[NSString stringWithFormat:@"--%@", httpBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableDictionary *allParameters = [NSMutableDictionary dictionaryWithCapacity:0];
    [allParameters addEntriesFromDictionary:[self extraParameters]];
    
    for (id key in [allParameters keyEnumerator]) {
        id value = [allParameters objectForKey:key];
        if ([value isKindOfClass:[NSString class]]) {
            [body appendData:[startLine dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[@"Content-Type: text/plain; charset=utf-8\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[(NSString*)value dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[endLine dataUsingEncoding:NSUTF8StringEncoding]];
        } else if ([value isKindOfClass:[NSNumber class]]) {
            [body appendData:[startLine dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[@"Content-Type: text/plain; charset=utf-8\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[(NSNumber*)value stringValue] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[endLine dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    for (NSDictionary *dict in fileData) {
        NSData *data = [dict objectForKey:@"data"];
        NSData *key = [dict objectForKey:@"key"];
        NSData *filename = [dict objectForKey:@"filename"];
        NSData *type = [dict objectForKey:@"type"];
        
        [body appendData:[startLine dataUsingEncoding:NSUTF8StringEncoding]];
        
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", key, filename] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", type] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:data];
        
        [body appendData:[endLine dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [body appendData:[@"--\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
}

- (void)generateUrlEncodedPostBody:(NSMutableURLRequest*)request {
    NSMutableDictionary *allParameters = [NSMutableDictionary dictionaryWithCapacity:0];
    [allParameters addEntriesFromDictionary:[self extraParameters]];
    
    NSData *thisPostData = [allParameters formEncodedPostData];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:thisPostData];
}


#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection*)aConnection didReceiveResponse:(NSURLResponse*)inResponse {
    responseData = [[NSMutableData alloc] init];
    expectedContentLength = [inResponse expectedContentLength];
    downloadedLength = 0;
    
    if ([inResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        self.response = (NSHTTPURLResponse*)inResponse;
    }
}

- (void)connection:(NSURLConnection*)aConnection didReceiveData:(NSData*)data {
    downloadedLength += [data length];
    
    if (responseData) {
        [responseData appendData:data];
    }
    
    if (expectedContentLength != NSURLResponseUnknownLength) {
        if (self.progressHandler) {
            float p = (float)downloadedLength / (float)expectedContentLength;
            self.progressHandler(NO, p);
        }
    }
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if (self.progressHandler) {
        float p = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        self.progressHandler(YES, p);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)aConnection {
    [self handleResponseData];
    responseData = nil;
    connection = nil;
}

- (void)connection:(NSURLConnection*)aConnection didFailWithError:(NSError*)error {  
    [self failWithError:error];
    responseData = nil;
    connection = nil;
}


#pragma mark - Default methods

- (NSString*)url {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException 
                                   reason:[NSString stringWithFormat:@"Subclasses must override %@.", NSStringFromSelector(_cmd)] 
                                 userInfo:nil];
}

- (NSDictionary*)extraParameters {
    return nil;
}

- (NSDictionary*)extraGetParameters {
    return nil;
}

- (id)handleResult:(NSData*)result error:(NSError**)error {
    return result;
}


#pragma mark -

- (id)init {
    if ((self = [super init])) {
        expectedContentLength = NSURLResponseUnknownLength;
        downloadedLength = 0;
        
        fileData = [[NSMutableArray alloc] initWithCapacity:0];
        
        connection = nil;
        responseData = nil;
    }
    return self;
}

@end
