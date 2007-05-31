/*
  Copyright (c) 2007, Marcus Müller <znek@mulle-kybernetik.com>.
  All rights reserved.


  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  - Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

  - Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

  - Neither the name of Mulle kybernetiK nor the names of its contributors
    may be used to endorse or promote products derived from this software
    without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
*/

#import "common.h"
#import "iTunesTrack.h"
#import "NSString+Extensions.h"
#import "NSURL+Extensions.h"

@interface iTunesTrack (Private)
- (void)setPrettyName:(NSString *)_prettyName;
- (void)setUrl:(NSURL *)_url;
- (NSURL *)url;
- (void)setAttributes:(NSDictionary *)_attributes;
- (NSDictionary *)attributes;
@end

@implementation iTunesTrack

static BOOL detailedNames = NO;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit       = YES;
  ud            = [NSUserDefaults standardUserDefaults];
  detailedNames = [ud boolForKey:@"DetailedTrackNames"];
}

/* init & dealloc */

- (id)initWithITunesLibraryRepresentation:(NSDictionary *)_track {
  self = [super init];
  if (self) {
    NSString            *name, *artist, *album;
    NSNumber            *trackNumber;
    NSString            *location;
    NSMutableString     *pn;
    NSMutableDictionary *attrs;
    id                  tmp;

    pn = [[NSMutableString alloc] initWithCapacity:128];
    if (detailedNames) {
      artist = [_track objectForKey:@"Artist"];
      if (artist) {
        [pn appendString:[artist properlyEscapedFSRepresentation]];
        [pn appendString:@"_"];
      }
      album = [_track objectForKey:@"Album"];
      if (album) {
        [pn appendString:[album properlyEscapedFSRepresentation]];
        [pn appendString:@"_"];
      }
      trackNumber = [_track objectForKey:@"Track Number"];
      if (trackNumber) {
        [pn appendString:[trackNumber description]];
        [pn appendString:@" "];
      }
    }
    name = [_track objectForKey:@"Name"];
    if (name) {
      [pn appendString:[name properlyEscapedFSRepresentation]];
    }
    else {
      NSLog(@"WARN: track without name! REP:%@", _track);
      [pn appendString:@"Empty"];
    }
#if 0
    [pn appendString:@" ["];
    [pn appendString:_trackID];
    [pn appendString:@"]"];
#endif
    location = [_track objectForKey:@"Location"];
    if (location) {
      [pn appendString:@"."];
      if ([location hasPrefix:@"file"]) {
        [pn appendString:[location pathExtension]];
      }
      else {
        /* http:// stream address... */
        [pn appendString:@"webloc"];
      }
      [self setUrl:[NSURL URLWithString:location]];
    }
    [self setPrettyName:pn];
    attrs = [[NSMutableDictionary alloc] initWithCapacity:3];
    if ([[self url] isFileURL]) {
      tmp = [_track objectForKey:@"Size"];
      if (tmp)
        [attrs setObject:tmp forKey:NSFileSize];
    }
    tmp = [_track objectForKey:@"Date Added"];
    if (tmp)
      [attrs setObject:tmp forKey:NSFileCreationDate];
    tmp = [_track objectForKey:@"Date Modified"];
    if (tmp) {
      [attrs setObject:tmp forKey:NSFileModificationDate];
    }
    else {
      tmp = [_track objectForKey:@"Play Date UTC"];
      if (tmp)
        [attrs setObject:tmp forKey:NSFileModificationDate];
    }
    [self setAttributes:attrs];
    [attrs release];
  }
  return self;
}

- (id)initWithIPodLibraryRepresentation:(NSDictionary *)_track {
  self = [super init];
  if (self) {
    NSString            *name, *artist, *album;
    NSNumber            *trackNumber;
    NSURL               *location;
    NSMutableString     *pn;
    NSMutableDictionary *attrs;
    id                  tmp;

    pn = [[NSMutableString alloc] initWithCapacity:128];
    if (detailedNames) {
      artist = [_track objectForKey:@"Artist"];
      if (artist) {
        [pn appendString:[artist properlyEscapedFSRepresentation]];
        [pn appendString:@"_"];
      }
      album = [_track objectForKey:@"Album"];
      if (album) {
        [pn appendString:[album properlyEscapedFSRepresentation]];
        [pn appendString:@"_"];
      }
      trackNumber = [_track objectForKey:@"Track Number"];
      if (trackNumber) {
        [pn appendString:[trackNumber description]];
        [pn appendString:@" "];
      }
    }
    name = [_track objectForKey:@"name"];
    if (name) {
      [pn appendString:[name properlyEscapedFSRepresentation]];
    }
    else {
      NSLog(@"WARN: track without name! REP:%@", _track);
      [pn appendString:@"Empty"];
    }
#if 0
    [pn appendString:@" ["];
    [pn appendString:_trackID];
    [pn appendString:@"]"];
#endif
    location = [_track objectForKey:@"location"];
    if (location) {
      [pn appendString:@"."];
      if ([location isFileURL]) {
        [pn appendString:[[location path] pathExtension]];
      }
      else {
        [pn appendString:@"webloc"];
      }
      [self setUrl:location];
    }
    [self setPrettyName:pn];

    attrs = [[NSMutableDictionary alloc] initWithCapacity:3];
    if ([[self url] isFileURL]) {
      tmp = [_track objectForKey:@"Size"];
      if (tmp)
        [attrs setObject:tmp forKey:NSFileSize];
    }
    tmp = [_track objectForKey:@"Date Added"];
    if (tmp)
      [attrs setObject:tmp forKey:NSFileCreationDate];
    tmp = [_track objectForKey:@"Date Modified"];
    if (tmp) {
      [attrs setObject:tmp forKey:NSFileModificationDate];
    }
    [self setAttributes:attrs];
    [attrs release];
  }
  return self;
}

- (void)dealloc {
  [self->prettyName release];
  [self->url        release];
  [self->attributes release];
  [super dealloc];
}

/* accessors */

- (void)setPrettyName:(NSString *)_prettyName {
  _prettyName = [_prettyName copy];
  [self->prettyName release];
  self->prettyName = _prettyName;
}
- (NSString *)prettyName {
  return self->prettyName;
}

- (void)setUrl:(NSURL *)_url {
  _url = [_url copy];
  [self->url release];
  self->url = _url;
}
- (NSURL *)url {
  return self->url;
}

- (void)setAttributes:(NSDictionary *)_attributes {
  _attributes = [_attributes copy];
  [self->attributes release];
  self->attributes = _attributes;
}
- (NSDictionary *)attributes {
  return self->attributes;
}

/* iTunesFS lookup */

- (NSDictionary *)fileAttributes {
  return [self attributes];
}

- (NSData *)fileContents {
  NSString *path;

  if (!self->url) return nil;
  if (![self->url isFileURL]) { /* http based audio stream... */
    return [[self->url description] dataUsingEncoding:NSUTF8StringEncoding];
  }
  path = [self->url properlyEscapedPath];
  return [NSData dataWithContentsOfFile:path
                 options:NSMappedRead|NSUncachedRead
                 error:NULL];
}

- (BOOL)isFile {
  return YES;
}

/* debugging */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ 0x%x: name:%@ attrs:%@",
                                    NSStringFromClass(self->isa), self,
                                    [self prettyName], [self attributes]];
}

@end /* iTunesTrack */
