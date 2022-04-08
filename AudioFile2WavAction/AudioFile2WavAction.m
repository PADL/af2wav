//
//  AudioFile2WavAction.m
//  AudioFile2WavAction
//
//  Created by Luke Howard on 8/4/22.
//

#import "AudioFile2WavAction.h"
#import "ExtendedAudioFileConverter.h"

@implementation AudioFile2WavAction

- (id)runWithInput:(id)input error:(NSError * _Nullable *)pError
{
    *pError = nil;
    
    if ([input isKindOfClass:NSArray.class]) {
        for (id itemPath in input) {
            if (![itemPath isKindOfClass:NSString.class]) {
                continue;
            }
            
            NSURL *sourceURL = [NSURL fileURLWithPath:itemPath];
            NSURL *destinationURL = [[sourceURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"wav"];

            dispatch_group_t group = dispatch_group_create();

            ExtendedAudioFileConverter *converter = [[ExtendedAudioFileConverter alloc]
                                                     initWithSourceURL:itemPath destinationURL:destinationURL];

            converter.completionHandler = ^(NSError *error) {
                *pError = error;
                dispatch_group_leave(group);
            };
            
            dispatch_group_enter(group);
            [converter convertAudioFile];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            
            if (*pError != nil)
                break;
        }
    }

    return input;
}

@end
