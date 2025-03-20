// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef _XUA_BUFFER_LITE_H_
#define _XUA_BUFFER_LITE_H_

#ifdef __XC__
#include <xs1.h>
#include "xua.h"
#endif

#include <stdint.h>

//Currently only single frequency supported
#define NOMINAL_SR_DEVICE                 DEFAULT_FREQ
#define NOMINAL_SR_HOST                   DEFAULT_FREQ

#define DIV_ROUND_UP(n, d) (n / d + 1)  //Always rounds up to the next integer. Needed for 48001Hz case etc.
#define BIGGEST(a, b) (a > b ? a : b)

#define SOF_FREQ_HZ                       (8000 - ((2 - AUDIO_CLASS) * 7000) ) //1000 for FS or 8000 for HS
#define SOF_PERIOD                        ((unsigned)((XS1_TIMER_MHZ * 1e6) / SOF_FREQ_HZ))

//Defines for endpoint buffer sizes. Samples is total number of samples across all channels
#define MAX_OUT_SAMPLES_PER_SOF_PERIOD    (DIV_ROUND_UP(MAX_FREQ, SOF_FREQ_HZ) * NUM_USB_CHAN_OUT)
#define NOM_OUT_SAMPLES_PER_SOF_PERIOD    ((MAX_FREQ / SOF_FREQ_HZ) * NUM_USB_CHAN_OUT)
#define MAX_IN_SAMPLES_PER_SOF_PERIOD     (DIV_ROUND_UP(MAX_FREQ, SOF_FREQ_HZ) * NUM_USB_CHAN_IN)
#define NOM_IN_SAMPLES_PER_SOF_PERIOD     ((MAX_FREQ / SOF_FREQ_HZ) * NUM_USB_CHAN_IN)
#define MAX_OUTPUT_SLOT_SIZE              4
#define MAX_INPUT_SLOT_SIZE               4

#define OUT_AUDIO_BUFFER_SIZE_BYTES       (MAX_OUT_SAMPLES_PER_SOF_PERIOD * MAX_OUTPUT_SLOT_SIZE)
#define IN_AUDIO_BUFFER_SIZE_BYTES        (MAX_IN_SAMPLES_PER_SOF_PERIOD * MAX_INPUT_SLOT_SIZE)

#define OUT_FIFO_LENGTH                   (4 * MAX_OUT_SAMPLES_PER_SOF_PERIOD)
#define IN_FIFO_LENGTH                    (4 * MAX_IN_SAMPLES_PER_SOF_PERIOD)

#define OUT_FIFO_TARGET                   (NUM_USB_CHAN_OUT * ((OUT_FIFO_LENGTH / 2) / NUM_USB_CHAN_OUT))
#define IN_FIFO_TARGET                    (NUM_USB_CHAN_IN * ((IN_FIFO_LENGTH / 2) / NUM_USB_CHAN_IN))

// XUA Lite fixed point

#define XUA_LIGHT_FIXED_POINT_Q_BITS        10 //Including sign bit. 10b gets us to +511.999999 to -512.000000
#define XUA_LIGHT_FIXED_POINT_TOTAL_BITS    (sizeof(xua_lite_fixed_point_t) * 8)
#define XUA_LIGHT_FIXED_POINT_FRAC_BITS     (XUA_LIGHT_FIXED_POINT_TOTAL_BITS - XUA_LIGHT_FIXED_POINT_Q_BITS)
#define XUA_LIGHT_FIXED_POINT_ONE           (1 << XUA_LIGHT_FIXED_POINT_FRAC_BITS)
#define XUA_LIGHT_FIXED_POINT_MINUS_ONE     (-XUA_LIGHT_FIXED_POINT_ONE)

typedef int32_t xua_lite_fixed_point_t;

// Instrumentation struct

enum nudge {
    NUDGE_UP,
    NUDGE_NONE,
    NUDGE_DOWN
};

typedef struct {
    // Buffer over/under flow
    int h2d_full;
    int h2d_empty;
    int d2h_full;
    int d2h_empty;

    // Timing
    unsigned sof_time;
    int sof_diff;
    unsigned recv_samples_delay;

    // PID state
    unsigned fill;
    xua_lite_fixed_point_t co; // (PID) Controller out
    enum nudge u_nudge;
} instrument_t;

struct XUA_host_status {
    char streaming_in, streaming_out;
    char seen_in, seen_out; // Cleared at SOF
};

#ifdef __XC__
unsafe void XUA_Buffer_lite(
    chanend ?c_aud_ctl,
    chanend c_aud_out,
    chanend ?c_feedback,
    chanend c_aud_in,
    chanend c_sof,
    in port ?p_for_mclk_count,
#if( 0 < HID_CONTROLS )
    chanend c_hid,
#endif
    chanend c_audio_hub);

#endif // __XC__

#endif // _XUA_BUFFER_LITE_H_
