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

#include "DDP.h"

#include <dlfcn.h>

static void *dlHandle;

bool
RegisterDDPComponent(void)
{
    if (dlHandle)
        return true;
    
    AudioComponent ddpCodec;
    AudioComponentFactoryFunction ddpFactory;
    
    AudioComponentDescription ddpDesc = {
        .componentType = kAudioDecoderComponentType,
        .componentSubType = 'ec+3',
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };

    dlHandle = dlopen("/System/Library/Components/AudioCodecs.component/Contents/MacOS/AudioCodecs", RTLD_NOW | RTLD_LOCAL);
    if (dlHandle == NULL) {
        return NULL;
    }
    
    ddpFactory = dlsym(dlHandle, "ACAC3DecoderNewFactory");
    if (ddpFactory == NULL) {
        dlclose(dlHandle);
        return NULL;
    }

    ddpCodec = AudioComponentRegister(&ddpDesc, CFSTR("Apple Enhanced AC3+ Decoder"), 0xffff, ddpFactory);
    
    return !!ddpCodec;
}

static void
UnregisterDDPComponent(void) __attribute__((__destructor__));

static void
UnregisterDDPComponent(void)
{
    if (dlHandle) {
        dlclose(dlHandle);
        dlHandle = NULL;
    }
}
