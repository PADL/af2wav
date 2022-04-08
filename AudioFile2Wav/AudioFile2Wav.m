//
//  AudioFile2Wav.m
//  AudioFile2Wav
//
//  Created by Luke Howard on 8/4/22.
//

#import "AudioFile2Wav.h"
#import "ExtendedAudioFileConverter.h"

@implementation AudioFile2Wav

- (id)runWithInput:(id)input error:(NSError **)pError
{
    *pError = nil;
    
    if ([input isKindOfClass:NSArray.class]) {
        for (id itemPath in input) {
            if (![itemPath isKindOfClass:NSString.class]) {
                continue;
            }
            
            __block NSError *error = nil;
            dispatch_group_t group = dispatch_group_create();
            NSURL *sourceURL = [NSURL fileURLWithPath:itemPath];
            NSURL *destinationURL = [[sourceURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"wav"];
            ExtendedAudioFileConverter *converter = [[ExtendedAudioFileConverter alloc]
                                                     initWithSourceURL:itemPath destinationURL:destinationURL];

            converter.completionHandler = ^(NSError *e) {
                error = e;
                dispatch_group_leave(group);
            };
            
            dispatch_group_enter(group);
            [converter convertAudioFile];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            
            if ((*pError = error) != nil)
                break;
        }
    }

    return input;
}

@end
