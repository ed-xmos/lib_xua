// Copyright (c) 2016-2018, XMOS Ltd, All rights reserved

#include <platform.h>
#include <print.h>

#include "xua.h"
#include "AudioConfig.h"


void UserBufferManagementInit(unsigned samFreq)
{
    printstr("UserBufferManagementInit\n");
}

void UserBufferManagement(unsigned sampsFromUsbToAudio[], unsigned sampsFromAudioToUsb[])
{
}


void AudioHwInit()
{
    printstr("AudioHwInit\n");

#if NODE == 0
    SetupPll(MCLK_48);
#endif
}

unsafe chanend c_samp_freq_glob = null;
void setup_chanend(chanend c_samp_freq){
    unsafe{
        c_samp_freq_glob = c_samp_freq;
    }
}

void AudioHwConfig(unsigned samFreq, unsigned mClk, unsigned dsdMode,
    unsigned sampRes_DAC, unsigned sampRes_ADC)
{

#if NODE == 0
    SetupPll(mClk);
#endif

    unsafe{
        if((unsigned)c_samp_freq_glob != 0){
            c_samp_freq_glob <: samFreq;
        }
        else{
            //Do nothing - chanend not setup yet
        }
    }
}

