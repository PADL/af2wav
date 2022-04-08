//
//  AudioFile2WavAction.h
//  AudioFile2WavAction
//
//  Created by Luke Howard on 8/4/22.
//

#import <Automator/AMBundleAction.h>

@interface AudioFile2WavAction : AMBundleAction

- (id)runWithInput:(id)input error:(NSError * _Nullable *)error;

@end
