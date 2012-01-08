//
//  MJGHTTPDownload.m
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

#import "MJGHTTPDownload.h"

@interface MJGHTTPDownload () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@property (nonatomic, copy) MJGHTTPDownloadHandler handler;
@property (nonatomic, copy) MJGHTTPDownloadProgressHandler progressHandler;

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *filename;

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSFileHandle *responseFileHandle;
@property (nonatomic, assign) long long expectedContentLength;
@property (nonatomic, assign) long long downloadedLength;

- (void)failWithError:(NSError*)error;
- (void)finish;
@end

@implementation MJGHTTPDownload

@synthesize handler = _handler, progressHandler = _progressHandler;
@synthesize url = _url, filename = _filename;
@synthesize connection = _connection, response = _response, responseFileHandle = _responseFileHandle, expectedContentLength = _expectedContentLength, downloadedLength = _downloadedLength;

#pragma mark -

- (id)initWithURL:(NSString*)inUrl downloadFilename:(NSString*)inFilename {
    if ((self = [self init])) {
        _url = [inUrl copy];
        _filename = [inFilename copy];
    }
    return self;
}

+ (MJGHTTPDownload*)requestWithURL:(NSString*)inUrl downloadFilename:(NSString*)inFilename {
    return [[MJGHTTPDownload alloc] initWithURL:inUrl downloadFilename:inFilename];
}


#pragma mark - Custom accessors

- (float)progress {
    return (float)((double)_downloadedLength / (double)_expectedContentLength);
}


#pragma mark -

- (void)startWithHandler:(MJGHTTPDownloadHandler)inHandler {
    [self startWithHandler:inHandler progressHandler:nil];
}

- (void)startWithHandler:(MJGHTTPDownloadHandler)inHandler progressHandler:(MJGHTTPDownloadProgressHandler)inProgressHandler {
    _handler = inHandler;
    _progressHandler = inProgressHandler;
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:_url]
                                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                            timeoutInterval:30.0];
    [request setHTTPMethod:@"GET"];
    
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if ([fileManager fileExistsAtPath:_filename]) {
        // Try to restart the download
        NSError *error = nil;
        NSDictionary *fileAttributes = [fileManager attributesOfItemAtPath:_filename error:&error];
        NSNumber *fileSize = [fileAttributes objectForKey:NSFileSize];
        if (!error && fileSize) {
            unsigned long long bytes = [fileSize unsignedLongLongValue];
            [request setValue:[NSString stringWithFormat:@"bytes=%llu-", bytes] forHTTPHeaderField:@"Range"];
        } else {
            [fileManager removeItemAtPath:_filename error:nil];
            [fileManager createFileAtPath:_filename contents:nil attributes:nil];
        }
    } else {
        // Just create a new file
        [fileManager createFileAtPath:_filename contents:nil attributes:nil];
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

- (void)finish {
    if (_handler) {
        _handler(_filename, _response, nil);
    }
}


#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection*)aConnection didReceiveResponse:(NSURLResponse*)inResponse {
    _expectedContentLength = [inResponse expectedContentLength];
    _downloadedLength = 0;
    
    _responseFileHandle = nil;
    
    if ([inResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        _response = (NSHTTPURLResponse*)inResponse;
        
        NSInteger statusCode = [_response statusCode];
        if (statusCode >= 200 && statusCode <= 299) {
            _responseFileHandle = [NSFileHandle fileHandleForWritingAtPath:_filename];
            
            NSString *contentRangeHeader = [[_response allHeaderFields] objectForKey:@"Content-Range"];
            NSString *removePrefix = [contentRangeHeader stringByReplacingOccurrencesOfString:@"bytes " withString:@""];
            NSArray *splitSlash = [removePrefix componentsSeparatedByString:@"/"];
            if (splitSlash.count == 2) {
                NSArray *splitDash = [[splitSlash objectAtIndex:0] componentsSeparatedByString:@"-"];
                if (splitDash.count == 2) {
                    NSString *startByte = [splitDash objectAtIndex:0];
                    unsigned long long bytes = strtoull([startByte UTF8String], NULL, 0);
                    @try {
                        [_responseFileHandle seekToFileOffset:bytes];
                        _expectedContentLength += bytes;
                        _downloadedLength += bytes;
                    } @catch (NSException *e) {
                        [_connection cancel];
                        _connection = nil;
                        [self failWithError:nil];
                    }
                }
            }
        } else if (statusCode == 416) {
            [_connection cancel];
            _connection = nil;
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            [fileManager removeItemAtPath:_filename error:nil];
            [self startWithHandler:_handler progressHandler:_progressHandler];
        } else {
            [_connection cancel];
            _connection = nil;
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain 
                                                 code:NSURLErrorUnknown 
                                             userInfo:nil];
            [self failWithError:error];
        }
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)aConnection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
    return nil;
}

- (void)connection:(NSURLConnection*)aConnection didReceiveData:(NSData*)data {
    _downloadedLength += [data length];
    
    if (_responseFileHandle) {
        [_responseFileHandle writeData:data];
        [_responseFileHandle synchronizeFile];
    }
    
    if (_expectedContentLength != NSURLResponseUnknownLength) {
        if (_progressHandler) {
            _progressHandler([self progress]);
        }
    }
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
}

- (NSCachedURLResponse*)connection:(NSURLConnection*)aConnection willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection*)aConnection {
    [self finish];
    _responseFileHandle = nil;
    _connection = nil;
}

- (void)connection:(NSURLConnection*)aConnection didFailWithError:(NSError*)error {  
    [self failWithError:error];
    _responseFileHandle = nil;
    _connection = nil;
}


#pragma mark -

- (id)init {
    if ((self = [super init])) {
        _expectedContentLength = NSURLResponseUnknownLength;
        _downloadedLength = 0;
    }
    return self;
}

- (void)dealloc {
    [_connection cancel];
}

@end
