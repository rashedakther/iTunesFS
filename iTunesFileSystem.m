/*
  Copyright (c) 2007, Marcus M�ller <znek@mulle-kybernetik.com>.
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
#import "iTunesFileSystem.h"
#import "iTunesLibrary.h"
#import "iPodLibrary.h"
#import "JBiPodLibrary.h"
#import "NSObject+FUSEOFS.h"

@interface iTunesFileSystem (Private)
- (void)addLibrary:(iTunesLibrary *)_lib;
- (void)removeLibrary:(iTunesLibrary *)_lib;
- (void)didMountRemovableDevice:(NSNotification *)_notif;
- (void)didUnmountRemovableDevice:(NSNotification *)_notif;

- (BOOL)showLibraries;

- (NSArray *)pathFromFSPath:(NSString *)_path;
- (id)lookupPath:(NSString *)_path;

- (BOOL)needsLocalOption;
@end

@implementation iTunesFileSystem

static BOOL     doDebug          = NO;
static BOOL     ignoreITunes     = NO;
static BOOL     ignoreIPods      = NO;
static NSString *fsIconPath      = nil;
static NSArray  *fakeVolumePaths = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;
  NSBundle       *mb;
  
  if (didInit) return;
  didInit         = YES;
  ud              = [NSUserDefaults standardUserDefaults];
  doDebug         = [ud boolForKey:@"iTunesFileSystemDebugEnabled"];
  ignoreITunes    = [ud boolForKey:@"NoITunes"];
  ignoreIPods     = [ud boolForKey:@"NoIPods"];
  if (ignoreITunes && ignoreIPods)
    NSLog(@"ERROR: ignoring iTunes and iPods doesn't make sense at all.");
  fakeVolumePaths = [[ud arrayForKey:@"iPodMountPoints"] copy];
  mb              = [NSBundle mainBundle];
#ifndef GNU_GUI_LIBRARY
  fsIconPath      = [[mb pathForResource:@"iTunesFS" ofType:@"icns"] copy];
  NSAssert(fsIconPath != nil, @"Couldn't find iTunesFS.icns!");
#endif
}

/* notifications */

- (void)fuseWillMount {
  iTunesLibrary *lib;

  self->libMap = [[NSMutableDictionary alloc] initWithCapacity:3];
  self->volMap = [[NSMutableDictionary alloc] initWithCapacity:3];

  // add default library
  if (!ignoreITunes) {
    lib = [[iTunesLibrary alloc] init];
    [self addLibrary:lib];
    [lib release];
  }
  if (!ignoreIPods) {
    NSArray              *volPaths;
    unsigned             i, count;
    NSNotificationCenter *nc;

    // add mounted iPods
    lib      = nil;
    volPaths = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
    if (fakeVolumePaths)
      volPaths = [volPaths arrayByAddingObjectsFromArray:fakeVolumePaths];
    count    = [volPaths count];
    for (i = 0; i < count; i++) {
      NSString *path;
      
      path = [volPaths objectAtIndex:i];
      if ([iPodLibrary isIPodAtMountPoint:path]) {
        lib = [[iPodLibrary alloc] initWithMountPoint:path];
      }
      else if ([JBiPodLibrary isIPodAtMountPoint:path]) {
        lib = [[JBiPodLibrary alloc] initWithMountPoint:path];
      }
      
      if (lib) {
        [self addLibrary:lib];
        [lib release];
        lib = nil;
      }
    }
    
    // mount/unmount registration
    nc = [[NSWorkspace sharedWorkspace] notificationCenter];
    [nc addObserver:self
        selector:@selector(didMountRemovableDevice:)
        name:NSWorkspaceDidMountNotification
        object:nil];
    [nc addObserver:self
        selector:@selector(willUnmountRemovableDevice:)
        name:NSWorkspaceWillUnmountNotification
        object:nil];
    [nc addObserver:self
        selector:@selector(didUnmountRemovableDevice:)
        name:NSWorkspaceDidUnmountNotification
        object:nil];
  }
}

- (void)fuseDidUnmount {
  NSNotificationCenter *nc;

  nc = [[NSWorkspace sharedWorkspace] notificationCenter];
  [nc removeObserver:self];

  [self->libMap release];
  [self->volMap release];
}

- (void)didMountRemovableDevice:(NSNotification *)_notif {
  NSString *path;

  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  if ([iPodLibrary isIPodAtMountPoint:path] ||
      [JBiPodLibrary isIPodAtMountPoint:path]) 
  {
    iTunesLibrary *lib;
    BOOL          prevShowLibraries;

    prevShowLibraries = [self showLibraries];
    if (doDebug) NSLog(@"Will add library for iPod at path: %@", path);
    if ([iPodLibrary isIPodAtMountPoint:path])
      lib = [[iPodLibrary alloc] initWithMountPoint:path];
    else
      lib = [[JBiPodLibrary alloc] initWithMountPoint:path];
    [self addLibrary:lib];
    [lib release];

    if ([self showLibraries] != prevShowLibraries) {
      if (doDebug)
        NSLog(@"posting -noteFileSystemChanged: for %@", [self mountPoint]);
      [[NSWorkspace sharedWorkspace] noteFileSystemChanged:[self mountPoint]];
    }
  }
}

- (void)willUnmountRemovableDevice:(NSNotification *)_notif {
  NSString      *path;
  iTunesLibrary *lib;
  
  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  lib  = [self->volMap objectForKey:path];
  if (lib) {
    if (doDebug)
      NSLog(@"Will close library for unmounting iPod at path: %@", path);
    [lib close];
  }
}

- (void)didUnmountRemovableDevice:(NSNotification *)_notif {
  NSString      *path;
  iTunesLibrary *lib;

  path = [[_notif userInfo] objectForKey:@"NSDevicePath"];
  lib  = [self->volMap objectForKey:path];
  if (lib) {
    BOOL prevShowLibraries;

    if (doDebug)
      NSLog(@"Will remove library for unmounted iPod at path: %@", path);
    [self removeLibrary:lib];

    if ([self showLibraries] != prevShowLibraries) {
      if (doDebug)
        NSLog(@"posting -noteFileSystemChanged: for %@", [self mountPoint]);
      [[NSWorkspace sharedWorkspace] noteFileSystemChanged:[self mountPoint]];
    }
  }
}

/* adding/removing libraries */

- (void)addLibrary:(iTunesLibrary *)_lib {
  NSString *path;

  path = [_lib mountPoint];
  if (path)
    [self->volMap setObject:_lib forKey:path];
  [self->libMap setObject:_lib forKey:[_lib name]];
}

- (void)removeLibrary:(iTunesLibrary *)_lib {
  NSString *path;

  path = [_lib mountPoint];
  if (path)
    [self->volMap removeObjectForKey:path];
  [self->libMap removeObjectForKey:[_lib name]];
}

/* private */

- (BOOL)showLibraries {
  if (ignoreIPods) return NO;
  if ([self->libMap count] == 1) return NO;
  return YES;
}

/* override */
- (NSArray *)pathFromFSPath:(NSString *)_path {
  NSArray *path;

  path = [super pathFromFSPath:_path];
  if (![self showLibraries]) {
    NSMutableArray *fakePath;
    
    /* We're not showing the library list by faking the only existing
     * library into the path - the lookup will then be done as usual.
     */
    fakePath = [path mutableCopy];
    [fakePath insertObject:[[self->libMap allKeys] lastObject] atIndex:1];
    path = [fakePath autorelease];
  }
  return path;
}

/* FUSEOFS */

- (id)lookupPathComponent:(NSString *)_pc {
  // TODO: add fake Spotlight entries
  return [self->libMap lookupPathComponent:_pc];
}

- (NSArray *)directoryContents {
  // TODO: fake Spotlight database
  return [self->libMap directoryContents];
}

- (NSDictionary *)fileSystemAttributes {
  NSMutableDictionary *attrs;
  
  attrs = [[NSMutableDictionary alloc] initWithCapacity:2];
  //    [attrs setObject:defaultSize forKey:NSFileSystemSize];
  [attrs setObject:[NSNumber numberWithInt:0] forKey:NSFileSystemFreeSize];
  return [attrs autorelease];
}

- (BOOL)isDirectory {
  return YES;
}

/* optional */

- (BOOL)usesResourceForks {
  return YES;
}

/* Finder in 10.5.{1|2} is braindead, only displays filesystems
 * marked as "local" in sidebar
 */
- (BOOL)needsLocalOption {
  NSString *osVer = [[NSProcessInfo processInfo] operatingSystemVersionString];
  
  if ([osVer rangeOfString:@"10.5"].length != 0) return YES;
  return NO;
}

- (NSArray *)fuseOptions {
  NSMutableArray *os;
  
  os = [[[super fuseOptions] mutableCopy] autorelease];
#if 0
  // careful!
  [os addObject:@"debug"];
#endif
  [os addObject:@"ping_diskarb"];
  if ([self needsLocalOption])
    [os addObject:@"local"];
  return os;
}

- (NSString *)iconFileForPath:(NSString *)_path {
  if ([_path isEqualToString:@"/"]) return fsIconPath;
  return nil;
}

/* debugging */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [[NSMutableString alloc] initWithCapacity:60];
  [ms appendString:@"<"];
  [ms appendFormat:@"%@ 0x%x", NSStringFromClass(self->isa), self];
  [ms appendString:@": #libs:"];
  [ms appendFormat:@"%d", [self->libMap count]];
  if (!ignoreIPods) {
    [ms appendString:@" #iPods:"];
    [ms appendFormat:@"%d", [self->volMap count]];
  }
  [ms appendString:@">"];
  return [ms autorelease];
}

@end
