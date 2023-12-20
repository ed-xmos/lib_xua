#include <xccompat.h>
#include <string.h>

#include "xua_xud_wrapper.h"


int XUD_Main_wrapper(chanend c_epOut[], int noEpOut,
                chanend c_epIn[], int noEpIn,
                NULLABLE_RESOURCE(chanend, c_sof),
                XUD_EpType epTypeTableOut[], XUD_EpType epTypeTableIn[],
                XUD_BusSpeed_t desiredSpeed,
                XUD_PwrConfig pwrConfig)
{
    int ret = 0;
#if NODE==0
    ret = XUD_Main(c_epOut, noEpOut, c_epIn, noEpIn,
                          c_sof, epTypeTableOut, epTypeTableIn,
                          desiredSpeed, pwrConfig);
#endif
    return ret;
}

int XUD_Main_wrapper_2(chanend c_epOut[], int noEpOut,
                chanend c_epIn[], int noEpIn,
                NULLABLE_RESOURCE(chanend, c_sof),
                XUD_EpType epTypeTableOut[], XUD_EpType epTypeTableIn[],
                XUD_BusSpeed_t desiredSpeed,
                XUD_PwrConfig pwrConfig)
{
    int ret = 0;
#if NODE==1
    ret = XUD_Main(c_epOut, noEpOut, c_epIn, noEpIn,
                          c_sof, epTypeTableOut, epTypeTableIn,
                          desiredSpeed, pwrConfig);
#endif
    return ret;
}

// XUA does not currently allow C to call XUA_Endpoint0
extern void XUA_Endpoint0(  chanend c_ep0_out,
                            chanend c_ep0_in,
                            NULLABLE_RESOURCE(chanend, c_audioCtrl),
                            NULLABLE_RESOURCE(chanend, c_mix_ctl),
                            NULLABLE_RESOURCE(chanend, c_clk_ctl),
                            NULLABLE_RESOURCE(chanend, c_EANativeTransport_ctrl),
                            NULLABLE_RESOURCE(chanend, dfuInterface));

void XUA_Endpoint0_wrapper( chanend c_ep0_out,
                            chanend c_ep0_in,
                            NULLABLE_RESOURCE(chanend, c_audioCtrl),
                            NULLABLE_RESOURCE(chanend, c_mix_ctl),
                            NULLABLE_RESOURCE(chanend, c_clk_ctl),
                            NULLABLE_RESOURCE(chanend, c_EANativeTransport_ctrl),
                            NULLABLE_RESOURCE(chanend, dfuInterface))
{
#if NODE==0
    XUA_Endpoint0(c_ep0_out, c_ep0_in, c_audioCtrl, c_mix_ctl, c_clk_ctl, c_EANativeTransport_ctrl, dfuInterface);
#endif
}

void XUA_Endpoint0_wrapper_2( chanend c_ep0_out,
                            chanend c_ep0_in,
                            NULLABLE_RESOURCE(chanend, c_audioCtrl),
                            NULLABLE_RESOURCE(chanend, c_mix_ctl),
                            NULLABLE_RESOURCE(chanend, c_clk_ctl),
                            NULLABLE_RESOURCE(chanend, c_EANativeTransport_ctrl),
                            NULLABLE_RESOURCE(chanend, dfuInterface))
{
#if NODE==1
    XUA_Endpoint0(c_ep0_out, c_ep0_in, c_audioCtrl, c_mix_ctl, c_clk_ctl, c_EANativeTransport_ctrl, dfuInterface);
#endif
}

// XUA does not currently allow C to call XUA_Buffer
void XUA_Buffer(chanend c_ep_out_1,
                chanend c_ep_in_2,
                chanend c_ep_in_1,
                chanend c_sof,
                chanend c_aud_ctl,
                IN_PORT p_for_mclk_count,
                chanend c_aud);

void XUA_Buffer_wrapper(chanend c_ep_out_1,
                        chanend c_ep_in_2,
                        chanend c_ep_in_1,
                        chanend c_sof,
                        chanend c_aud_ctl,
                        IN_PORT p_for_mclk_count,
                        chanend c_aud)
{
#if NODE==0
    XUA_Buffer(c_ep_out_1, c_ep_in_2, c_ep_in_1, c_sof, c_aud_ctl, p_for_mclk_count, c_aud);
#endif
}

void XUA_Buffer_wrapper_2(chanend c_ep_out_1,
                        chanend c_ep_in_2,
                        chanend c_ep_in_1,
                        chanend c_sof,
                        chanend c_aud_ctl,
                        IN_PORT p_for_mclk_count,
                        chanend c_aud)
{
#if NODE==1
    XUA_Buffer(c_ep_out_1, c_ep_in_2, c_ep_in_1, c_sof, c_aud_ctl, p_for_mclk_count, c_aud);
#endif
}

// XUA does not currently allow C to call XUA_AudioHub
void XUA_AudioHub(chanend c_aud,
                xcore_clock_t clk_audio_mclk,
                xcore_clock_t clk_audio_bclk,
                IN_PORT p_mclk_in,
                out_buffered_port_32_t p_lrclk,
                out_buffered_port_32_t p_bclk,
                out_buffered_port_32_t p_i2s_dac[],
                in_buffered_port_32_t p_i2s_adc[]);

void XUA_AudioHub_wrapper(  chanend c_aud,
                            xcore_clock_t clk_audio_mclk,
                            xcore_clock_t clk_audio_bclk,
                            IN_PORT p_mclk_in,
                            out_buffered_port_32_t p_lrclk,
                            out_buffered_port_32_t p_bclk,
                            out_buffered_port_32_t p_i2s_dac[],
                            in_buffered_port_32_t p_i2s_adc[])
{
#if NODE==0
    XUA_AudioHub(c_aud, clk_audio_mclk, clk_audio_bclk, p_mclk_in, p_lrclk, p_bclk, p_i2s_dac, p_i2s_adc);
#endif
}

void XUA_AudioHub_wrapper_2(chanend c_aud,
                            xcore_clock_t clk_audio_mclk,
                            xcore_clock_t clk_audio_bclk,
                            IN_PORT p_mclk_in,
                            out_buffered_port_32_t p_lrclk,
                            out_buffered_port_32_t p_bclk,
                            out_buffered_port_32_t p_i2s_dac[],
                            in_buffered_port_32_t p_i2s_adc[])
{
#if NODE==1
    XUA_AudioHub(c_aud, clk_audio_mclk, clk_audio_bclk, p_mclk_in, p_lrclk, p_bclk, p_i2s_dac, p_i2s_adc);
#endif
}

