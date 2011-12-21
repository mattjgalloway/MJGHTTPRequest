//
//  BeerMapApiRequest.m
//  MJGHTTPRequestDemo
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

#import "BeerMapApiRequest.h"

@interface BeerMapApiRequest ()
@property (nonatomic, copy) NSString *apiPath;
@end

@implementation BeerMapApiRequest

@synthesize apiPath;

#pragma mark -

- (id)initWithApiPath:(NSString*)inApiPath requestMethod:(MJGHTTPRequestMethod)method {
    if ((self = [super initWithRequestMethod:method])) {
        self.apiPath = inApiPath;
    }
    return self;
}


#pragma mark -

- (NSString*)url {
    return [NSString stringWithFormat:@"http://bmapi.mynet.org.uk/v2/%@", apiPath];
}

- (NSDictionary*)extraParameters {
    return nil;
}

- (NSDictionary*)extraGetParameters {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"json", @"format",
            nil];
}

- (id)handleResult:(NSData*)result error:(NSError**)error {
    NSError *jsonError = nil;
    NSDictionary *outResult = [NSJSONSerialization JSONObjectWithData:result 
                                                              options:0 
                                                                error:&jsonError];
    if (jsonError) {
        if (error) {
            *error = jsonError;
        }
        return nil;
    }
    
    return outResult;
}

@end
