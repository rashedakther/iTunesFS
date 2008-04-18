/*
  Copyright (c) 2007-2008, Marcus Müller <znek@mulle-kybernetik.com>.
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
#import "JBiPodLibrary.h"

@implementation JBiPodLibrary

+ (BOOL)isIPodAtMountPoint:(NSString *)_path {
  NSString *testPath;
  
  /* simple heuristic for Jailbreaked iPods
   * NOTE: My iPhone 1.1.4 says: <mnt>/var/mobile/Media/iTunes_Control/...
   */
  testPath = [NSString stringWithFormat:@"%@/Media/iTunes_Control", _path];
  return [[NSFileManager defaultManager] fileExistsAtPath:testPath];
}

- (NSString *)iTunesDeviceInfoPath {
  return nil;
}

- (NSString *)iTunesMusicFolderPath {
  return [NSString stringWithFormat:@"%@/Media/iTunes_Control/Music/",
                                    [self mountPoint]];
}

- (NSString *)libraryPath {
  return [NSString stringWithFormat:@"%@/Media/iTunes_Control/iTunes/iTunesDB",
                                    [self mountPoint]];
}

@end /* JBiPodLibrary */
