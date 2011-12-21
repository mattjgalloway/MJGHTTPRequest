//
//  NSDictionary-HTTP.m
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

#import "NSDictionary-HTTP.h"

@implementation NSDictionary (HTTP)

- (NSString*)getQuery {
    NSMutableArray *pairs = [[NSMutableArray alloc] initWithCapacity:0];
    for (NSString *key in [self keyEnumerator]) {
        id value = [self objectForKey:key];
        
        // TODO: Support more than just NSString and NSNumber
        
        if ([value isKindOfClass:[NSString class]]) {
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", 
                              [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], 
                              [(NSString*)value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        } else if ([value isKindOfClass:[NSNumber class]]) {
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", 
                              [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], 
                              [[(NSNumber*)value stringValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        }
    }
    return [pairs componentsJoinedByString:@"&"];
}

- (NSData*)formEncodedPostData {
    return [[self getQuery] dataUsingEncoding:NSUTF8StringEncoding];
}

@end
