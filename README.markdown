# MJGHTTPRequest

## Introduction

MJGHTTPRequest is a class designed to be subclassed to take the pain out of performing HTTP 
requests on iOS. Most HTTP APIs have a base URL that's the same (e.g. api.twitter.com) and take 
certain parameters. They also usually return a given format of data such as JSON or XML. 
MJGHTTPRequest enables you to create your own class to talk to these APIs and handle all the HTTP 
level things for you. All you need to do is hook into whatever mechanism you want to handle the 
returned data which might be passing it through a JSON or XML deserialiser for example.

## License

MJGHTTPRequest uses the 2-clause BSD license. So you should be free to use it pretty much however 
you want. Contact me if you require further information.

Copyright (c) 2011 Matt Galloway. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Automatic Reference Counting (ARC)

This project uses ARC.

## Author

MJGHTTPRequest is written and maintained by Matt Galloway <http://iphone.galloway.me.uk>.

## How to use

### Adding MJGHTTPRequest to your project ###

All you need to do to get started is to add everything in the `Source` folder to your project.

### Subclassing MJGHTTPRequest ###

We will assume there is a HTTP API which is based at http://api.example.com/v1/ which has the 
following methods:

`search` - takes a single paramter `term` and returns an array of results. Result will be found in 
under the key `results` in the returned object.
`upload` - takes files to be uploaded to the server and returns success or failure.

In addition, all methods are required to have a `format` paremeter set in the query part of the URL 
to indicate either `json` or `xml` return types. We will use `json`. The API defines that every 
request will return a JSON object with the data in it.

 1. Create a class which inherits from `MJGHTTPRequest`:

    #import "MJGHTTPRequest.h"
    @interface MyApiRequest : MJGHTTPRequest
    @property (nonatomic, strong) NSString *path;
    @end

 1. Implement the required methods:

    @implementation MyApiRequest
    
    @synthesize path;
    
    - (NSString*)url {
        return [NSString stringWithFormat:@"http://api.example.com/v1/%@", path];
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
        // We know our API is returning a JSON object, so lets deserialise it and return the object
        
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

 1. Now use the subclass to peform a search:

    MyApiRequest *request = [[MyApiRequest alloc] initWithRequestMethod:MJGHTTPRequestMethodGET];
    request.path = @"search";
    request.parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"bunnies", @"term", nil];
    [request startWithHandler:^(id result, NSHTTPURLResponse *response, NSError *error){
        if (!error) {
            // Yay the request worked!
            NSArray *results = [(NSDictionary*)result objectForKey:@"results"];
            NSLog(@"Results:\n%@", results);
        } else {
            // Ooops! Error!
        }
    }];

 1. And now upload a picture:

    UIImage *image = <UIImage_from_somewhere>;
    MyApiRequest *request = [[MyApiRequest alloc] initWithRequestMethod:MJGHTTPRequestMethodPOST];
    request.postMethod = MJGHTTPRequestPOSTMethodFormData;
    request.path = @"upload";
    [request addFileData:UIImagePNGRepresentation(image) 
                  forKey:@"image" 
            withFilename:@"image.png" 
                    type:@"image/png"];
    [request startWithHandler:^(id result, NSHTTPURLResponse *response, NSError *error){
        if (!error) {
            // Yay the request worked!
        } else {
            // Ooops! Error!
        }
    }];
