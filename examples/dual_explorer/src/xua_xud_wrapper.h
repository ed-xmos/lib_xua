#include <xccompat.h>

#pragma once

#include "xud.h"
#include "xua.h"

// Not supported by xccompat so define here
#ifdef __XC__
#define IN_PORT in port
#else
#define IN_PORT unsigned
#endif


int XUD_Main_wrapper(chanend c_epOut[], int noEpOut,
                chanend c_epIn[], int noEpIn,
                NULLABLE_RESOURCE(chanend, c_sof),
                XUD_EpType epTypeTableOut[], XUD_EpType epTypeTableIn[],
                XUD_BusSpeed_t desiredSpeed,
                XUD_PwrConfig pwrConfig);

void XUA_Endpoint0_wrapper( chanend c_ep0_out,
                            chanend c_ep0_in,
                            NULLABLE_RESOURCE(chanend, c_audioCtrl),
                            NULLABLE_RESOURCE(chanend, c_mix_ctl),
                            NULLABLE_RESOURCE(chanend, c_clk_ctl),
                            NULLABLE_RESOURCE(chanend, c_EANativeTransport_ctrl),
                            NULLABLE_RESOURCE(chanend, dfuInterface));

void XUA_Buffer_wrapper(chanend c_ep_out_1,
                        chanend c_ep_in_2,
                        chanend c_ep_in_1,
                        chanend c_sof,
                        chanend c_aud_ctl,
                        IN_PORT p_for_mclk_count,
                        chanend c_aud);

void XUA_AudioHub_wrapper(  chanend c_aud,
                            xcore_clock_t clk_audio_mclk,
                            xcore_clock_t clk_audio_bclk,
                            IN_PORT p_mclk_in,
                            out_buffered_port_32_t p_lrclk,
                            out_buffered_port_32_t p_bclk,
                            out_buffered_port_32_t p_i2s_dac[],
                            in_buffered_port_32_t p_i2s_adc[]);