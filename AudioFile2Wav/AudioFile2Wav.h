//
//  AudioFile2Wav.h
//  AudioFile2Wav
//
//  Created by Luke Howard on 8/4/22.
//

#import <Automator/AMBundleAction.h>

@interface AudioFile2Wav : AMBundleAction

- (id)runWithInput:(id)input error:(NSError **)error;

@end
