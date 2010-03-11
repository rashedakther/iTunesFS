/*
  Copyright (c) 2007-2010, Marcus Müller <znek@mulle-kybernetik.com>.
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
#import "iTunesPlaylist.h"
#import "iTunesLibrary.h"
#import "iTunesTrack.h"
#import "NSString+Extensions.h"
#import "iTunesFSFormatter.h"

@interface iTunesPlaylist (Private)
- (void)generatePrettyTrackNames;
- (void)setName:(NSString *)_name;
- (void)setTracks:(NSArray *)_tracks;
- (void)setTrackNames:(NSArray *)_trackNames;
@end

@implementation iTunesPlaylist

static BOOL              doDebug           = NO;
static iTunesFSFormatter *plTrackFormatter = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  NSString       *fmt;
  
  if (didInit) return;
  didInit          = YES;
  ud               = [NSUserDefaults standardUserDefaults];
  doDebug          = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  fmt              = [ud stringForKey:@"PlaylistsTrackFormat"];
  plTrackFormatter = [[iTunesFSFormatter alloc] initWithFormatString:fmt];
  
  if (doDebug)
    NSLog(@"PlaylistsTrackFormat: %@", fmt);
}

- (id)initWithITunesLibraryRepresentation:(NSDictionary *)_list
  lib:(iTunesLibrary *)_lib
{
  self = [super init];
  if (self) {
    BOOL isFolder;

    self->persistentId = [[_list objectForKey:@"Playlist Persistent ID"] copy];
    self->parentId     = [[_list objectForKey:@"Parent Persistent ID"] copy];
    [self setName:[_list objectForKey:@"Name"]];

    isFolder = [[_list objectForKey:@"Folder"] boolValue];

    if (!isFolder) {
      NSArray        *items;
      unsigned       i, count;
      NSMutableArray *ma;

      items = [_list objectForKey:@"Playlist Items"];
      count = [items count];
      ma    = [[NSMutableArray alloc] initWithCapacity:count];

      for (i = 0; i < count; i++) {
        NSDictionary *item;
        NSString     *trackID;
        iTunesTrack  *trk;

        item    = [items objectAtIndex:i];
        trackID = [[item objectForKey:@"Track ID"] description];
        trk     = [_lib trackWithID:trackID];
        if (!trk) {
  #if 0
          /* NOTE: Rolf's library really sports these effects, seems to be
           * limited to Podcasts only.
           */
          NSLog(@"INFO Playlist[%@]: found no track item for #%@",
                self->name, trackID);
  #endif
          continue;
        }
        [ma addObject:trk];
      }
      [self setTracks:ma];
      [ma release];
      [self generatePrettyTrackNames];
    }
    else {
      self->childrenMap = [[NSMutableDictionary alloc] initWithCapacity:5];
    }
  }
  return self;
}

- (id)initWithIPodLibraryRepresentation:(NSDictionary *)_list
  lib:(iTunesLibrary *)_lib
{
  self = [super init];
  if (self) {
    NSArray        *items;
    NSMutableArray *ma;
    unsigned       i, count;
    
    [self setName:[_list objectForKey:@"name"]];

    items = [_list objectForKey:@"trackIDs"];
    count = [items count];
    ma = [[NSMutableArray alloc] initWithCapacity:count];
    for (i = 0; i < count; i++) {
      NSString     *trackID;
      iTunesTrack  *trk;
      
      trackID = [items objectAtIndex:i];
      trk     = [_lib trackWithID:trackID];
      if (!trk) {
#if 0
        /* NOTE: Rolf's library really sports these effects, seems to be
        * limited to Podcasts only.
        */
        NSLog(@"INFO Playlist[%@]: found no track item for #%@",
              self->name, trackID);
#endif
        continue;
      }
      [ma addObject:trk];
    }
    [self setTracks:ma];
    [ma release];
    [self generatePrettyTrackNames];
  }
  return self;
}

- (void)dealloc {
  [self->persistentId release];
  [self->parentId     release];
  [self->name         release];
  [self->tracks       release];
  [self->trackNames   release];
  [self->childrenMap  release];
  [super dealloc];
}

/* private */

- (void)generatePrettyTrackNames {
  NSMutableArray *ma;
  unsigned       i, count;

  count = [self->tracks count];
  ma    = [[NSMutableArray alloc] initWithCapacity:count];
  for (i = 0; i < count; i++) {
    iTunesTrack *trk;
    unsigned    trkIndex;
    NSString    *tn;
    
    trk      = [self trackAtIndex:i];
    trkIndex = i + 1;
    [trk setPlaylistNumber:trkIndex];
    tn       = [plTrackFormatter stringValueByFormattingObject:trk];
    [ma addObject:tn];
  }
  [self setTrackNames:ma];
  [ma release];
}

/* accessors */

- (void)setName:(NSString *)_name {
  _name = [[_name properlyEscapedFSRepresentation] copy];
  [self->name release];
  self->name = _name;
}
- (NSString *)name {
  return self->name;
}

- (NSString *)persistentId {
  return self->persistentId;
}
- (NSString *)parentId {
  return self->parentId;
}

- (void)setTracks:(NSArray *)_tracks {
  _tracks = [_tracks copy];
  [self->tracks release];
  self->tracks = _tracks;
}
- (NSArray *)tracks {
  return self->tracks;
}

- (unsigned)count {
  return [self->tracks count];
}

- (iTunesTrack *)trackAtIndex:(unsigned)_idx {
  return [self->tracks objectAtIndex:_idx];
}

- (void)setTrackNames:(NSArray *)_trackNames {
  _trackNames = [_trackNames copy];
  [self->trackNames release];
  self->trackNames = _trackNames;
}
- (NSArray *)trackNames {
  return self->trackNames;
}

- (void)addChild:(iTunesPlaylist *)_child withName:(NSString *)_name {
  [self->childrenMap setObject:_child
                     forKey:[_name properlyEscapedFSRepresentation]];
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc inContext:(id)_ctx {
  // NOTE: it's either children or tracks, never both!
  if (self->childrenMap)
    return [self->childrenMap objectForKey:_pc];

  NSUInteger idx;

  idx = [[self trackNames] indexOfObject:_pc];
  if (idx == NSNotFound) return nil;
  return [self trackAtIndex:idx];
}
- (NSArray *)directoryContents {
  // NOTE: it's either children or tracks, never both!
  if (self->childrenMap)
    return [self->childrenMap allKeys];
  return [self trackNames];
}
- (BOOL)isDirectory {
  return YES;
}

#if 0

// NOTE: in theory this should do the trick of hiding the .fpbf extension,
// however this flag has been removed from Finder.h altogether and it doesn't
// work in practice (tested on 10.5.6)

- (NSDictionary *)finderAttributes {
		NSNumber *finderFlags = [NSNumber numberWithLong:0x0010];
		return [NSDictionary dictionaryWithObject:finderFlags
                         forKey:kGMUserFileSystemFinderFlagsKey];
}
#endif

/* debugging */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ 0x%x: name:%@ #tracks:%d>",
                                    NSStringFromClass(self->isa), self,
                                    [self name], [self count]];
}

@end /* iTunesPlaylist */
