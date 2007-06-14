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
#import "iTunesLibrary.h"
#import <AppKit/AppKit.h>
#import "NSString+Extensions.h"
#import "iTunesPlaylist.h"
#import "iTunesTrack.h"
#import "Watchdog.h"
#import "NSObject+Extensions.h"

@implementation iTunesLibrary

static BOOL     doDebug       = NO;
static BOOL     useCategories = NO;
static BOOL     mimicIPodNav  = NO;
static NSString *libraryPath  = nil;
static NSImage  *libraryIcon  = nil;
static NSString *kPlaylists   = nil;
static NSString *kArtists     = nil;
static NSString *kAlbums      = nil;
static NSString *kSongs       = nil;
static NSString *kUnknown     = nil;
static NSString *kAll         = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  
  if (didInit) return;
  didInit       = YES;
  ud            = [NSUserDefaults standardUserDefaults];
  doDebug       = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  useCategories = [ud boolForKey:@"UseCategories"];
  libraryPath   = [[[ud stringForKey:@"Library"] stringByStandardizingPath]
                                                 copy];
  if (!libraryPath) {
    libraryPath = [[NSHomeDirectory() stringByAppendingString:
                                      @"/Music/iTunes/iTunes Music Library.xml"]
                                      copy];
  }
  libraryIcon = [[[NSWorkspace sharedWorkspace]
                               iconForFile:@"/Applications/iTunes.app"]
                               copy];

  kPlaylists  = [[NSLocalizedString(@"Playlists", "Playlists")
                                   properlyEscapedFSRepresentation] copy];
  kAlbums     = [[NSLocalizedString(@"Albums",    "Albums")
                                   properlyEscapedFSRepresentation] copy];
  kArtists    = [[NSLocalizedString(@"Artists",   "Artists")
                                   properlyEscapedFSRepresentation] copy];
  kSongs      = [[NSLocalizedString(@"Songs",     "Songs")
                                   properlyEscapedFSRepresentation] copy];
  kUnknown    = [[NSLocalizedString(@"Unknown",   "Unknown")
                                   properlyEscapedFSRepresentation] copy];
  kAll        = [[NSLocalizedString(@"All",       "All")
                                   properlyEscapedFSRepresentation] copy];

  if (doDebug && useCategories)
    NSLog(@"Using categories (virtual folder hierarchy)");
}

- (id)init {
  self = [super init];
  if (self) {
    self->plMap    = [[NSMutableDictionary alloc] initWithCapacity:128];
    self->trackMap = [[NSMutableDictionary alloc] initWithCapacity:10000];
    if (useCategories) {
      NSMutableDictionary *tmp;

      self->virtMap = [[NSMutableDictionary alloc] initWithCapacity:3];
      tmp = [[NSMutableDictionary alloc] initWithCapacity:1000];
      [self->virtMap setObject:tmp forKey:kAlbums];
      [tmp release];
      tmp = [[NSMutableDictionary alloc] initWithCapacity:1000];
      [self->virtMap setObject:tmp forKey:kArtists];
      [tmp release];
    }
    [self reload];
    [[Watchdog sharedWatchdog] watchLibrary:self];
  }
  return self;
}

- (void)dealloc {
  [self close];
  [self->name     release];
  [self->plMap    release];
  [self->trackMap release];
  [self->virtMap  release];
  [super dealloc];
}

/* setup */

- (void)reload {
  NSData        *plist;
  NSDictionary  *lib;
  NSArray       *playlists;
  NSDictionary  *tracks;
  NSArray       *trackIDs;
  unsigned      i, count;

  if (doDebug)
    NSLog(@"%s", __PRETTY_FUNCTION__);

  [self->plMap    removeAllObjects];
  [self->trackMap removeAllObjects];
  plist = [NSData dataWithContentsOfFile:[self libraryPath]];
  NSAssert1(plist != nil, @"Couldn't read contents of %@!",
                          [self libraryPath]);

  lib = [NSPropertyListSerialization propertyListFromData:plist
                                     mutabilityOption:NSPropertyListImmutable
                                     format:NULL
                                     errorDescription:NULL];
  NSAssert1(lib != nil, @"Couldn't parse contents of %@ - wrong format?!",
                        [self libraryPath]);

  [self->name release];
  self->name = [[NSString stringWithFormat:@"iTunes (v%@)",
                          [lib objectForKey:@"Application Version"]] copy];

  tracks    = [lib objectForKey:@"Tracks"];
  trackIDs  = [tracks allKeys];
  count     = [trackIDs count];
  for (i = 0; i < count; i++) {
    NSString     *trackID;
    NSDictionary *rep;
    iTunesTrack  *track;

    trackID = [trackIDs objectAtIndex:i];
    rep     = [tracks objectForKey:trackID];
    track   = [[iTunesTrack alloc] initWithITunesLibraryRepresentation:rep];
    [self->trackMap setObject:track forKey:trackID];
    [track release];
  }
  
  playlists = [lib objectForKey:@"Playlists"];
  count     = [playlists count];
  for (i = 0; i < count; i++) {
    NSDictionary   *plRep;
    iTunesPlaylist *pl;

    plRep = [playlists objectAtIndex:i];
    pl    = [[iTunesPlaylist alloc] initWithITunesLibraryRepresentation:plRep
                                    lib:self];
    [self->plMap setObject:pl forKey:[pl name]];
    [pl release];
  }
  [self reloadVirtualMaps];
}

- (void)reloadVirtualMaps {
  NSMutableDictionary *albums, *artists;
  NSArray             *tracks;
  unsigned            count, i;

  if (!useCategories) return;

  [self->virtMap removeObjectForKey:kPlaylists];
  [self->virtMap removeObjectForKey:kSongs];

  if ([self->plMap count] == 1) {
    // TODO: this needs to be another key, then
    [self->virtMap setObject:[[self->plMap allValues] lastObject]
                   forKey:kSongs];
  }
  else {
    [self->virtMap setObject:self->plMap forKey:kPlaylists];
  }

  albums  = [self->virtMap objectForKey:kAlbums];
  artists = [self->virtMap objectForKey:kArtists];
  
  [albums  removeAllObjects];
  [artists removeAllObjects];

  tracks = [self->trackMap allValues];
  count  = [tracks count];
  for (i = 0; i < count; i++) {
    iTunesTrack *track;
    NSString            *artist, *album;
    NSMutableDictionary *artistAlbums, *albumTracks;

    track  = [tracks objectAtIndex:i];
    artist = [track artist];
    if (!artist) artist = kUnknown;
    album  = [track album];
    if (!album)  album  = kUnknown;
    
    artistAlbums = [artists objectForKey:artist];
    if (!artistAlbums) {
      artistAlbums = [[NSMutableDictionary alloc] initWithCapacity:2];
      [artists setObject:artistAlbums forKey:artist];
      [artistAlbums release];
    }
    albumTracks = [artistAlbums objectForKey:album];
    if (!albumTracks) {
      albumTracks = [[NSMutableDictionary alloc] initWithCapacity:10];
      [artistAlbums setObject:albumTracks forKey:album];
      [albumTracks release];
    }
    // TODO: apply formatter here
    [albumTracks setObject:track forKey:[track prettyName]];
    
    // now, for albums only
    albumTracks = [albums objectForKey:album];
    if (!albumTracks) {
      albumTracks = [[NSMutableDictionary alloc] initWithCapacity:10];
      [albums setObject:albumTracks forKey:album];
      [albumTracks release];
    }
    // TODO: apply formatter here
    [albumTracks setObject:track forKey:[track prettyName]];
  }

  if (mimicIPodNav) {
    /* optimize artistAlbums hierarchy, insert "All" if there is more than
     * one album per artist
     */
    NSArray *allAlbums;

    allAlbums = [artists allValues];
    count     = [allAlbums count];
    for (i = 0; i < count; i++) {
      NSMutableDictionary *artistAlbums;
      unsigned            aCount, k;

      artistAlbums = [allAlbums objectAtIndex:i];
      aCount       = [artistAlbums count];
      if (aCount > 1) {
        NSArray             *allArtistAlbums;
        NSMutableDictionary *allTracks;
        
        allTracks = [[NSMutableDictionary alloc] initWithCapacity:10 * aCount];
        [artistAlbums setObject:allTracks forKey:kAll];
        [allTracks release];

        allArtistAlbums = [artistAlbums allValues];
        for (k = 0; k < aCount; k++) {
          NSDictionary *albumTracks;

          albumTracks = [allArtistAlbums objectAtIndex:k];
          /* NOTE:
           * This doesn't avoid collisions!!
           * It's unsuitable for COPYING content, though browsing does work
           * to some extent...
           */
          [allTracks addEntriesFromDictionary:albumTracks];
        }
      }
    }
  }
  
}

- (void)close {
  [[Watchdog sharedWatchdog] forgetLibrary:self];
}

/* accessors */

- (NSString *)name {
  if (!doDebug) return @"iTunes";
  return self->name;
}
- (NSImage *)icon {
  return libraryIcon;
}
- (NSString *)libraryPath {
  return libraryPath;
}
- (NSString *)mountPoint {
  return nil;
}

- (NSArray *)playlistNames {
  return [self->plMap allKeys];
}
- (iTunesPlaylist *)playlistNamed:(NSString *)_plName {
  return [self->plMap objectForKey:_plName];
}


- (iTunesTrack *)trackWithID:(NSString *)_trackID {
  return [self->trackMap objectForKey:_trackID];
}

/* iTunesFS lookup */

- (id)lookupPathComponent:(NSString *)_pc {
  if (!useCategories) {
    unsigned count;
    
    count = [self->plMap count];
    if (count == 0) return nil;
    if (count == 1)
      return [[[self->plMap allValues] lastObject] lookupPathComponent:_pc];
    return [self playlistNamed:_pc];
  }
  return [self->virtMap lookupPathComponent:_pc];
}

- (NSArray *)directoryContents {
  if (!useCategories) {
    if ([self->plMap count] != 1)
      return [self playlistNames];
    return [[[self->plMap allValues] lastObject] directoryContents];
  }
  return [self->virtMap directoryContents];
}

- (BOOL)isDirectory {
  return YES;
}

/* debugging */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ 0x%x: name:%@ path:%@",
                                    NSStringFromClass(self->isa), self,
                                    [self name], [self libraryPath]];
}

@end /* iTunesLibrary */
