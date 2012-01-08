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

#if ! __has_feature(objc_arc)
#error This file requires ARC to be enabled. Either enable ARC for the entire project or use -fobjc-arc flag.
#endif

#import "MJGHTTPRequest.h"

#import "NSDictionary-HTTP.h"

@interface MJGHTTPRequest ()
@property (nonatomic, assign) MJGHTTPRequestMethod method;
@property (nonatomic, strong) NSData *rawPostData;
@property (nonatomic, copy) NSString *rawPostType;
@property (nonatomic, strong) NSMutableArray *fileData;

@property (nonatomic, copy) MJGHTTPRequestHandler handler;
@property (nonatomic, copy) MJGHTTPRequestProgressHandler progressHandler;

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, assign) long long expectedContentLength;
@property (nonatomic, assign) long long downloadedLength;

- (void)failWithError:(NSError*)error;
- (void)handleResponseData;

- (void)generateFormDataPostBody:(NSMutableURLRequest*)request;
- (void)generateUrlEncodedPostBody:(NSMutableURLRequest*)request;
@end

@implementation MJGHTTPRequest

@synthesize parameters = _parameters, postFormat = _postFormat;
@synthesize method = _method, rawPostData = _rawPostData, rawPostType = _rawPostType, fileData = _fileData;
@synthesize handler = _handler, progressHandler = _progressHandler;
@synthesize connection = _connection, response = _response, responseData = _responseData, expectedContentLength = _expectedContentLength, downloadedLength = _downloadedLength;

#pragma mark -

- (id)initWithRequestMethod:(MJGHTTPRequestMethod)inMethod {
    if ((self = [self init])) {
        _method = inMethod;
        _postFormat = MJGHTTPRequestMethodPOSTFormatURLEncode;
    }
    return self;
}

+ (MJGHTTPRequest*)requestWithRequestMethod:(MJGHTTPRequestMethod)method {
    return [[MJGHTTPRequest alloc] initWithRequestMethod:method];
}


#pragma mark -

- (void)setPOSTBody:(NSData*)data type:(NSString*)type {
    // We need to set the post method to raw data if we're setting the post body
    _postFormat = MJGHTTPRequestMethodPOSTFormatRawData;
    _rawPostData = data;
    _rawPostType = type;
}

- (void)addFileData:(NSData*)data forKey:(NSString*)key withFilename:(NSString*)filename type:(NSString*)type {
    // We need to set the post method to form data if we're adding files
    _postFormat = MJGHTTPRequestMethodPOSTFormatFormData;
    
    NSDictionary *newFileData = [NSDictionary dictionaryWithObjectsAndKeys:
                                 data, @"data",
                                 key, @"key",
                                 filename, @"filename",
                                 type, @"type",
                                 nil];
    [_fileData addObject:newFileData];
}

- (void)startWithHandler:(MJGHTTPRequestHandler)inHandler {
    [self startWithHandler:inHandler progressHandler:nil];
}

- (void)startWithHandler:(MJGHTTPRequestHandler)inHandler progressHandler:(MJGHTTPRequestProgressHandler)inProgressHandler {
    _handler = inHandler;
    _progressHandler = inProgressHandler;
    
    NSMutableString *url = [NSMutableString stringWithString:[self url]];
    
    NSMutableDictionary *allGetParameters = [NSMutableDictionary dictionaryWithCapacity:0];
    [allGetParameters addEntriesFromDictionary:[self extraGetParameters]];
    
    if (_method == MJGHTTPRequestMethodGET) {
        [allGetParameters addEntriesFromDictionary:[self extraParameters]];
        [allGetParameters addEntriesFromDictionary:_parameters];
    }
    
    if (allGetParameters.count > 0) {
        [url appendFormat:@"?%@", [allGetParameters getQuery]];
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                            timeoutInterval:30.0];
    
    if (_method == MJGHTTPRequestMethodGET) {
        [request setHTTPMethod:@"GET"];
    } else if (_method == MJGHTTPRequestMethodPOST) {
        [request setHTTPMethod:@"POST"];
        if (_postFormat == MJGHTTPRequestMethodPOSTFormatRawData) {
            [request setHTTPBody:_rawPostData];
            if (_rawPostType) {
                [request setValue:_rawPostType forHTTPHeaderField:@"Content-Type"];
            }
        } else if (_postFormat == MJGHTTPRequestMethodPOSTFormatFormData) {
            [self generateFormDataPostBody:request];
        } else if (_postFormat == MJGHTTPRequestMethodPOSTFormatURLEncode) {
            [self generateUrlEncodedPostBody:request];
        }
    }
    
    _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)cancel {
    [_connection cancel];
    _connection = nil;
}


#pragma mark -

- (void)failWithError:(NSError*)error {
    if (_handler) {
        _handler(nil, _response, error);
    }
}

- (void)handleResponseData {
    NSError *error = nil;
    id result = [self handleResult:_responseData error:&error];
    if (_handler) {
        _handler(result, _response, error);
    }
    _responseData = nil;
}


#pragma mark - POST body generation

- (void)generateFormDataPostBody:(NSMutableURLRequest*)request {
    NSString *httpBoundary = @"----MJGHTTPRequest0xce86d7d02a229acfaca4b63f01a1171b";
    
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", httpBoundary] forHTTPHeaderField:@"Content-Type"];
    
    NSMutableData *body = [[NSMutableData alloc] init];
    
    NSString *startLine = [NSString stringWithFormat:@"\r\n"];
    NSString *endLine = [NSString stringWithFormat:@"\r\n--%@", httpBoundary];
    
    [body appendData:[[NSString stringWithFormat:@"--%@", httpBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSMutableDictionary *allParameters = [NSMutableDictionary dictionaryWithDictionary:_parameters];
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
    
    for (NSDictionary *dict in _fileData) {
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
    NSMutableDictionary *allParameters = [NSMutableDictionary dictionaryWithDictionary:_parameters];
    [allParameters addEntriesFromDictionary:[self extraParameters]];
    
    NSData *thisPostData = [allParameters formEncodedPostData];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:thisPostData];
}


#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection*)aConnection didReceiveResponse:(NSURLResponse*)inResponse {
    _responseData = [[NSMutableData alloc] init];
    _expectedContentLength = [inResponse expectedContentLength];
    _downloadedLength = 0;
    
    if ([inResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        _response = (NSHTTPURLResponse*)inResponse;
    }
}

- (void)connection:(NSURLConnection*)aConnection didReceiveData:(NSData*)data {
    _downloadedLength += [data length];
    
    [_responseData appendData:data];
    
    if (_expectedContentLength != NSURLResponseUnknownLength) {
        if (_progressHandler) {
            float p = (float)_downloadedLength / (float)_expectedContentLength;
            _progressHandler(NO, p);
        }
    }
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if (_progressHandler) {
        float p = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        _progressHandler(YES, p);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)aConnection {
    [self handleResponseData];
    _responseData = nil;
    _connection = nil;
}

- (void)connection:(NSURLConnection*)aConnection didFailWithError:(NSError*)error {  
    [self failWithError:error];
    _responseData = nil;
    _connection = nil;
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
        _expectedContentLength = NSURLResponseUnknownLength;
        _downloadedLength = 0;
        
        _fileData = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

@end
