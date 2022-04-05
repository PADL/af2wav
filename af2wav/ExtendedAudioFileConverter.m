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

/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Demonstrates converting audio using ExtAudioFile.
 */

#import "ExtendedAudioFileConverter.h"

@import Darwin;
@import AVFoundation;

@implementation ExtendedAudioFileConverter
{
    AudioFormatListItem *_formatListItems;
    UInt8 *_magic;
    UInt32 _magicSize;
    double _lastPercentComplete;
}

- (void)dealloc {
    free(_formatListItems);
    free(_magic);
}

- (instancetype)initWithSourceURL:(NSURL *)sourceURL
                   destinationURL:(NSURL *)destinationURL {
    
    if ((self = [super init])) {
        _sourceURL = sourceURL;
        _destinationURL = destinationURL;
    }
    
    return self;
}

- (void)convertAudioFile {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self _convertAudioFile];
    });
}

- (void)_convertAudioFile {
    OSStatus error;
    ExtAudioFileRef sourceFile = NULL;
    AudioFileID audioFileID;
    AudioStreamBasicDescription sourceFormat = {};
    UInt32 size;

    // reinitialize in case called multiple times 
    free(_formatListItems);
    _formatListItems = NULL;

    free(_magic);
    _magic = NULL;
    _magicSize = 0;

    if (![self checkError:ExtAudioFileOpenURL((__bridge CFURLRef _Nonnull)(self.sourceURL), &sourceFile)
          withErrorString:[NSString stringWithFormat:@"ExtAudioFileOpenURL failed for sourceFile with URL: %@", self.sourceURL]]) {
        return;
    }
    
    size = sizeof(sourceFormat);
    if (![self checkError:ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat)
          withErrorString:@"ExtAudioFileGetProperty couldn't get the source data format"]) {
        return;
    }

    size = sizeof(audioFileID);
    if (![self checkError:ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_AudioFile, &size, &audioFileID)
          withErrorString:@"ExtAudioFileGetProperty coudln't get audio file ID"]) {
        return;
    }

    error = AudioFileGetPropertyInfo(audioFileID, kAudioFilePropertyMagicCookieData, &_magicSize, NULL);
    if (error != noErr && error != kAudioFileStreamError_UnsupportedProperty) {
        [self checkError:error withErrorString:@"AudioFileGetProperty couldn't get magic cookie length"];
        return;
    }
    
    if (_magicSize != 0) {
        _magic = calloc(1, _magicSize);
        if (_magic == NULL) {
            [self checkError:cNoMemErr withErrorString:@"out of memory"];
            return;
        }
        
        if (![self checkError:AudioFileGetProperty(audioFileID, kAudioFilePropertyMagicCookieData, &_magicSize, _magic)
              withErrorString:@"AudioFileGetProperty couldn't get magic cookie"]) {
            return;
        }
        
        AudioFormatInfo formatInfo = {
            .mASBD = sourceFormat,
            .mMagicCookie = _magic,
            .mMagicCookieSize = _magicSize
        };

        UInt32 outputFormatInfoSize = 0;
        if (![self checkError:AudioFormatGetPropertyInfo(kAudioFormatProperty_FormatList, sizeof(formatInfo), &formatInfo, &outputFormatInfoSize)
              withErrorString:@"AudioFormatGetPropertyInfo couldn't get format list size"]) {
            return;
        }
        
        _formatListItems = calloc(1, outputFormatInfoSize);
        if (_formatListItems == NULL) {
            [self checkError:cNoMemErr withErrorString:@"out of memory"];
            return;
        }

        if (![self checkError:AudioFormatGetProperty(kAudioFormatProperty_FormatList, sizeof(formatInfo), &formatInfo, &outputFormatInfoSize, _formatListItems)
              withErrorString:@"AudioFormatGetProperty couldn't get format list"]) {
            return;
        }
        
        size_t itemCount = outputFormatInfoSize / sizeof(_formatListItems[0]);
        assert(itemCount > 0);

        sourceFormat = _formatListItems[0].mASBD;
    }
    
    // Setup the output file format.
    AudioStreamBasicDescription destinationFormat = {};
    destinationFormat.mSampleRate = sourceFormat.mSampleRate;
    
    destinationFormat.mFormatID = kAudioFormatLinearPCM;
    destinationFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
    destinationFormat.mBitsPerChannel = 32;
    destinationFormat.mBytesPerPacket = destinationFormat.mBytesPerFrame = 4 * destinationFormat.mChannelsPerFrame;
    destinationFormat.mFramesPerPacket = 1;
    destinationFormat.mFormatFlags = kLinearPCMFormatFlagIsPacked | kAudioFormatFlagIsFloat; // little-endian
    
    // Create the destination audio file.
    ExtAudioFileRef destinationFile = NULL;
    AudioFileTypeID typeID = [self.destinationURL.pathExtension caseInsensitiveCompare:@"caf"] == NSOrderedSame ? kAudioFileCAFType : kAudioFileWAVEType;
    
    if (![self checkError:ExtAudioFileCreateWithURL((__bridge CFURLRef _Nonnull)(self.destinationURL), typeID, &destinationFormat, NULL, kAudioFileFlags_EraseFile, &destinationFile)
          withErrorString:@"ExtAudioFileCreateWithURL failed!"]) {
        return;
    }
    
    size = sizeof(destinationFormat);
    if (![self checkError:ExtAudioFileSetProperty(sourceFile, kExtAudioFileProperty_ClientDataFormat, size, &destinationFormat)
          withErrorString:@"Couldn't set the client format on the source file!"]) {
        return;
    }
    
    size = sizeof(destinationFormat);
    if (![self checkError:ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, size, &destinationFormat)
          withErrorString:@"Couldn't set the client format on the destination file!"]) {
        return;
    }

    struct AudioChannelLayout layout = {0};

    if (_formatListItems) {
        if (typeID == kAudioFileWAVEType) {
            layout.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelBitmap;
            layout.mChannelBitmap = 0;
            switch (_formatListItems[0].mChannelLayoutTag) {
                case kAudioChannelLayoutTag_Atmos_7_1_2:
                case kAudioChannelLayoutTag_Atmos_7_1_4:
                    if (_formatListItems[0].mChannelLayoutTag == kAudioChannelLayoutTag_Atmos_7_1_2)
                        layout.mChannelBitmap |= kAudioChannelBit_LeftTopMiddle | kAudioChannelBit_RightTopMiddle;
                    else
                        layout.mChannelBitmap |= kAudioChannelBit_VerticalHeightLeft | kAudioChannelBit_VerticalHeightRight | kAudioChannelBit_TopBackLeft | kAudioChannelBit_TopBackRight;
                    /* fallthrough */
                case kAudioChannelLayoutTag_MPEG_7_1_C:
                    layout.mChannelBitmap |= kAudioChannelBit_LeftSurroundDirect | kAudioChannelBit_RightSurroundDirect;
                    /* fallthrough */
                case kAudioChannelLayoutTag_MPEG_5_1_A:
                case kAudioChannelLayoutTag_MPEG_5_1_B:
                case kAudioChannelLayoutTag_MPEG_5_1_C:
                case kAudioChannelLayoutTag_MPEG_5_1_D:
                    layout.mChannelBitmap |= kAudioChannelBit_LFEScreen;
                    /* fallthrough */
                case kAudioChannelLayoutTag_WAVE_5_0_B:
                case kAudioChannelLayoutTag_MPEG_5_0_A:
                case kAudioChannelLayoutTag_MPEG_5_0_B:
                case kAudioChannelLayoutTag_MPEG_5_0_C:
                case kAudioChannelLayoutTag_MPEG_5_0_D:
                case kAudioChannelLayoutTag_Pentagonal:
                    layout.mChannelBitmap |= kAudioChannelBit_Center;
                    /* fallthrough */
                case kAudioChannelLayoutTag_Quadraphonic:
                    layout.mChannelBitmap |= kAudioChannelBit_LeftSurround | kAudioChannelBit_RightSurround;
                    /* fallthrough */
                case kAudioChannelLayoutTag_Stereo:
                    layout.mChannelBitmap |= kAudioChannelBit_Left | kAudioChannelBit_Right;
                    break;
                default:
                    layout.mChannelLayoutTag = _formatListItems[0].mChannelLayoutTag;
                    break;
            }
        } else {
            layout.mChannelLayoutTag = _formatListItems[0].mChannelLayoutTag;
        }
        
        if (![self checkError:ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_FileChannelLayout, sizeof(layout), &layout)
              withErrorString:@"Couldn't set the layout tag on the destination file!"]) {
            return;
        }
    }

    if (self.preflightHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.preflightHandler(sourceFormat, destinationFormat, layout);
        });
    }
    
    // Get the audio converter.
    AudioConverterRef converter = NULL;
    
    size = sizeof(converter);
    if (![self checkError:ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &converter)
          withErrorString:@"Failed to get the Audio Converter from the destination file."]) {
        return;
    }
    
    SInt64 lengthInFrames = 0, sourceFrameOffset = 0;
    size = sizeof(lengthInFrames);
    if (![self checkError:ExtAudioFileGetProperty(sourceFile, kExtAudioFileProperty_FileLengthFrames, &size, &lengthInFrames)
          withErrorString:@"Failed to get length of source file in frames"]) {
        return;
    }

    UInt32 bufferByteSize = 32768;
    char sourceBuffer[bufferByteSize];
    
    AudioBufferList fillBufferList = {};
    
    fillBufferList.mNumberBuffers = 1;
    fillBufferList.mBuffers[0].mNumberChannels = destinationFormat.mChannelsPerFrame;
    fillBufferList.mBuffers[0].mDataByteSize = bufferByteSize;
    fillBufferList.mBuffers[0].mData = sourceBuffer;
    
    _lastPercentComplete = 0;
    
    while (true) {
        if (self.progressHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                double percentComplete = round((double)sourceFrameOffset / (double)lengthInFrames * 100.0);
                if (percentComplete != self->_lastPercentComplete)
                    self.progressHandler(percentComplete);
                self->_lastPercentComplete = percentComplete;
            });
        }
        
        /*
         The client format is always linear PCM - so here we determine how many frames of lpcm
         we can read/write given our buffer size
         */
        UInt32 numberOfFrames = 0;
        if (destinationFormat.mBytesPerFrame > 0) {
            // Handles bogus analyzer divide by zero warning mBytesPerFrame can't be a 0 and is protected by an Assert.
            numberOfFrames = bufferByteSize / destinationFormat.mBytesPerFrame;
        }
        
        if (![self checkError:ExtAudioFileRead(sourceFile, &numberOfFrames, &fillBufferList) withErrorString:@"ExtAudioFileRead failed!"]) {
            return;
        }

        if (numberOfFrames == 0) {
            error = noErr;
            break;
        }

        sourceFrameOffset += numberOfFrames;

        error = ExtAudioFileWrite(destinationFile, numberOfFrames, &fillBufferList);
        if (error != noErr) {
            [self checkError:error withErrorString:@"ExtAudioFileWrite failed!"];
            return;
        }
    }
    
    // Cleanup
    if (destinationFile)
        ExtAudioFileDispose(destinationFile);
    if (sourceFile)
        ExtAudioFileDispose(sourceFile);
    
    if (self.completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionHandler(nil);
        });
    }
}

- (bool)checkError:(OSStatus)error withErrorString:(NSString *)string {
    if (error == noErr) {
        return true;
    }
    
    NSError *nsError = [NSError errorWithDomain:NSOSStatusErrorDomain code:error userInfo:@{NSLocalizedDescriptionKey : string}];

    if (self.completionHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.completionHandler(nsError);
        });
    }
    
    return false;
}

+ (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}

@end
