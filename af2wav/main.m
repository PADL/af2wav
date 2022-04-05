/*
 * Copyright (c) 2022, PADL Software Pty Ltd.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted (subject to the limitations in the
 * disclaimer below) provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of PADL Software nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED
 * BY THIS LICENSE.  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

@import Foundation;
@import AudioToolbox;

#import "DDP.h"
#import "ExtendedAudioFileConverter.h"

#define PBSTR "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||"
#define PBWIDTH 60

int main(int argc, const char * argv[]) {
    if (!RegisterDDPComponent()) {
        fprintf(stderr, "Failed to register ec+3 codec\n");
        exit(2);
    }

    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "Usage: %s infile.m4a [outfile.wav|caf]\n", argv[0]);
            exit(1);
        }

        NSURL *sourceURL = [NSURL fileURLWithPath:[NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding]];
        NSURL *destinationURL;
        NSError *error;
        
        if (argc < 3) {
            destinationURL = [[sourceURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"wav"];
        } else {
            destinationURL = [NSURL fileURLWithPath:[NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding]];
        }

        ExtendedAudioFileConverter *converter = [[ExtendedAudioFileConverter alloc]
                                                 initWithSourceURL:sourceURL destinationURL:destinationURL];

        converter.preflightHandler = ^(AudioStreamBasicDescription sourceFormat,
                                       AudioStreamBasicDescription destinationFormat,
                                       AudioChannelLayout layout) {
            printf("Source file format:\n");
            [ExtendedAudioFileConverter printAudioStreamBasicDescription:sourceFormat];
            printf("Destination file format:\n");
            [ExtendedAudioFileConverter printAudioStreamBasicDescription:destinationFormat];
        };

        converter.progressHandler = ^(double percentage) {
            int val = (int)percentage;
            int lpad = (int)((percentage / 100.0) * PBWIDTH);
            int rpad = PBWIDTH - lpad;
            printf("\r%3d%% [%.*s%*s]", val, lpad, PBSTR, rpad, "");
            fflush(stdout);
            
            if (percentage == 100.0) {
                printf("\n");
            }
            
        };
        
        converter.completionHandler = ^(NSError *error) {
            if (error) {
                NSLog(@"%@", error);
                exit(3);
            } else {
                exit(0);
            }
        };
        
        [converter convertAudioFile];
        
        dispatch_main();
    }
    
    return 0;
}
