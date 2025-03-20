// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#include "xua_buffer_lite.h"
#include "feedback_calculation.h"

//Calculate feedback for asynchronous USB audio
void do_feedback_calculation(unsigned &sof_count
                                ,const unsigned mclk_hz
                                ,unsigned mclk_port_counter
                                ,unsigned &mclk_port_counter_old
                                ,long long &feedback_value
                                ,unsigned &mod_from_last_time
                                ,unsigned fb_clocks[1]){
  // Assuming 48kHz from a 24.576 master clock (0.0407uS period)
  // MCLK ticks per SOF = 125uS / 0.0407 = 3072 MCLK ticks per SOF.
  // expected Feedback is 48000/8000 = 6 samples. so 0x60000 in 16:16 format.
  // Average over 128 SOFs - 128 x 3072 = 0x60000.

  unsigned long long feedbackMul = 64ULL;
  if(AUDIO_CLASS == 1) feedbackMul = 8ULL;  // TODO Use 4 instead of 8 to avoid windows LSB issues?

  // Number of MCLK ticks in this SOF period (E.g = 125 * 24.576 = 3072)
  int mclk_ticks_this_sof_period = (int) ((short)(mclk_port_counter - mclk_port_counter_old));
  unsigned long long full_result = mclk_ticks_this_sof_period * feedbackMul * DEFAULT_FREQ;
  feedback_value += full_result;

  // Store MCLK for next time around...
  mclk_port_counter_old = mclk_port_counter;

  // Reset counts based on SOF counting.  Expect 16ms (128 HS SOFs/16 FS SOFS) per feedback poll
  // We always count 128 SOFs, so 16ms @ HS, 128ms @ FS
  if(sof_count == 128) {
    //debug_printf("fb\n");
    sof_count = 0;

    feedback_value += mod_from_last_time;
    unsigned clocks = feedback_value / mclk_hz;
    mod_from_last_time = feedback_value % mclk_hz;
    feedback_value = 0;

    //Scale for working out number of samps to take from device for input
    if(AUDIO_CLASS == 2){
        clocks <<= 3;
    }
    else{
        clocks <<= 6;
    }
    asm volatile("stw %0, dp[g_speed]"::"r"(clocks));   // g_speed = clocks

    //Write to feedback EP buffer
    if (AUDIO_CLASS == 2){
        fb_clocks[0] = clocks;
    }
    else{
        fb_clocks[0] = clocks >> 2;
    }
  }
}

