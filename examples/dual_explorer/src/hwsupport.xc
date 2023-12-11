// Copyright (c) 2016-2018, XMOS Ltd, All rights reserved

#include <platform.h>
#include <timer.h>
#include <stdint.h>

#include "xua.h"
#include "AudioConfig.h"
#include <stdio.h>
#include <print.h>


void UserBufferManagementInit(unsigned samFreq)
{
    printf("UserBufferManagementInit\n");
}

void UserBufferManagement(unsigned sampsFromUsbToAudio[], unsigned sampsFromAudioToUsb[])
{
}


void AudioHwInit()
{
    printf("AudioHwInit\n");

    SetupPll(MCLK_48);
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
    printf("AudioHwConfig, samFreq: %u, mclk: %u, sampRes_DAC: %u, sampRes_ADC: %u\n", samFreq, mClk, sampRes_DAC, sampRes_ADC);
    /*
    let me know if you need different settings for clocks, we can do 22.5792MHz exactly for 44.1kHz using the fractional-n part of appPLL

    there is a bug on the appPLL so you need to disable it before applying new PLL config write */
    
    SetupPll(mClk);

    unsafe{
        if((unsigned)c_samp_freq_glob != 0){
            c_samp_freq_glob <: samFreq;
        }
        else{
            //Do nothing - chanend not setup yet
        }
    }
}

