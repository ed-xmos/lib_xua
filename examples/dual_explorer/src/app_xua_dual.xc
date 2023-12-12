// Copyright (c) 2017-2018, XMOS Ltd, All rights reserved

/* A very simple *example* of a USB audio application (and as such is un-verified for production)
 *
 * It uses the main blocks from the lib_xua 
 *
 * - 2 in/ 2 out I2S only
 * - No DFU
 * - I2S only 
 *
 */

#include <xs1.h>
#include <platform.h>

#include "xua.h"
#include "AudioConfig.h"
extern "C"{
    #include "xua_xud_wrapper.h"
}

#define AUDIO_TILE_1    tile[1]
#define I2C_TILE_1      tile[0]
#define AUDIO_TILE_2    tile[3]
#define I2C_TILE_2      tile[2]

/////////////// INSTANCE 1 ///////////////////


/* Port declarations. Note, the defines come from the xn file */
on AUDIO_TILE_1: buffered out port:32 p_i2s_dac[]    = {XS1_PORT_1A};   /* I2S Data-line(s) */
on AUDIO_TILE_1: buffered in port:32 p_i2s_adc[]     = {XS1_PORT_1N};   /* I2S Data-line(s) */
on AUDIO_TILE_1: buffered out port:32 p_lrclk        = XS1_PORT_1B;     /* I2S L/R-clock */ 
on AUDIO_TILE_1: buffered out port:32 p_bclk         = XS1_PORT_1C;     /* I2S Bit-clock */
on AUDIO_TILE_1: out port p_codec_reset              = XS1_PORT_4A;     /* Bit 3 */

/* Master clock for the audio IO tile */
on AUDIO_TILE_1: in port p_mclk_in                   = XS1_PORT_1D;

/* Resources for USB feedback */
on AUDIO_TILE_1: in port p_for_mclk_count            = XS1_PORT_16A;   /* Extra port for counting master clock ticks */

/* Clock-block declarations */
clock clk_audio_bclk                = on AUDIO_TILE_1: XS1_CLKBLK_1;   /* Bit clock */    
clock clk_audio_mclk                = on AUDIO_TILE_1: XS1_CLKBLK_2;   /* Master clock */

/* Endpoint type tables - informs XUD what the transfer types for each Endpoint in use and also
 * if the endpoint wishes to be informed of USB bus resets */
XUD_EpType epTypeTableOut[]   = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_ISO};
XUD_EpType epTypeTableIn[]    = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_ISO, XUD_EPTYPE_ISO};

XUD_resources_t resources =
{
    on AUDIO_TILE_1: XS1_PORT_1E,            // flag0_port
    on AUDIO_TILE_1: XS1_PORT_1F,            // flag1_port
    null,                                    // flag2_port
    on AUDIO_TILE_1: XS1_PORT_1J,            // p_usb_clk
    on AUDIO_TILE_1: XS1_PORT_8A,            // p_usb_txd
    on AUDIO_TILE_1: XS1_PORT_8B,            // p_usb_rxd
    on AUDIO_TILE_1: XS1_PORT_1K,            // tx_readyout
    on AUDIO_TILE_1: XS1_PORT_1H,            // tx_readyin
    on AUDIO_TILE_1: XS1_PORT_1I,            // rx_rdy
    on AUDIO_TILE_1: XS1_CLKBLK_4,           // tx_usb_clk
    on AUDIO_TILE_1: XS1_CLKBLK_5,           // rx_usb_clk
};

// I2C interface ports
on I2C_TILE_1: port p_scl = XS1_PORT_1N;
on I2C_TILE_1: port p_sda = XS1_PORT_1O;


/////////////// INSTANCE 2 ///////////////////

/* Port declarations. Note, the defines come from the xn file */
on AUDIO_TILE_2: buffered out port:32 p_i2s_dac2[]    = {XS1_PORT_1A};   /* I2S Data-line(s) */
on AUDIO_TILE_2: buffered in port:32 p_i2s_adc2[]     = {XS1_PORT_1N};   /* I2S Data-line(s) */
on AUDIO_TILE_2: buffered out port:32 p_lrclk2        = XS1_PORT_1B;     /* I2S L/R-clock */ 
on AUDIO_TILE_2: buffered out port:32 p_bclk2         = XS1_PORT_1C;     /* I2S Bit-clock */
on AUDIO_TILE_2: out port p_codec_reset2              = XS1_PORT_4A;     /* Bit 3 */

/* Master clock for the audio IO tile */
on AUDIO_TILE_2: in port p_mclk_in2                   = XS1_PORT_1D;

/* Resources for USB feedback */
on AUDIO_TILE_2: in port p_for_mclk_count2            = XS1_PORT_16A;   /* Extra port for counting master clock ticks */

/* Clock-block declarations */
clock clk_audio_bclk2                = on AUDIO_TILE_2: XS1_CLKBLK_1;   /* Bit clock */    
clock clk_audio_mclk2                = on AUDIO_TILE_2: XS1_CLKBLK_2;   /* Master clock */

/* Endpoint type tables - informs XUD what the transfer types for each Endpoint in use and also
 * if the endpoint wishes to be informed of USB bus resets */

XUD_EpType epTypeTableOut2[]   = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_ISO};
XUD_EpType epTypeTableIn2[]    = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_ISO, XUD_EPTYPE_ISO};

XUD_resources_t resources2 =
{
    on AUDIO_TILE_2: XS1_PORT_1E,
    on AUDIO_TILE_2: XS1_PORT_1F,
    null,
    on AUDIO_TILE_2: XS1_PORT_1J,
    on AUDIO_TILE_2: XS1_PORT_8A,
    on AUDIO_TILE_2: XS1_PORT_8B,
    on AUDIO_TILE_2: XS1_PORT_1K,
    on AUDIO_TILE_2: XS1_PORT_1H,
    on AUDIO_TILE_2: XS1_PORT_1I,
    on AUDIO_TILE_2: XS1_CLKBLK_4,
    on AUDIO_TILE_2: XS1_CLKBLK_5,
};

// I2C interface ports
on I2C_TILE_2: port p_scl2 = XS1_PORT_1N;
on I2C_TILE_2: port p_sda2 = XS1_PORT_1O;


int main()
{
    /* Channels for lib_xud */
    chan c_ep_out[2];
    chan c_ep_in[3];

    chan c_ep_out2[2];
    chan c_ep_in2[3];

    /* Channel for communicating SOF notifications from XUD to the Buffering cores */
    chan c_sof;
    chan c_sof2;

    /* Channel for audio data between buffering cores and AudioHub/IO core */
    chan c_aud;
    chan c_aud2;
    
    /* Channel for communicating control messages from EP0 to the rest of the device (via the buffering cores) */
    chan c_aud_ctl;
    chan c_aud_ctl2;

    chan c_samp_freq;
    chan c_samp_freq2;

    par
    {
        /* Low level USB device layer core */ 
        on AUDIO_TILE_1:{
    
            setup_chanend(c_samp_freq);
            p_codec_reset <: 0xf; // Take out of reset

            set_port_clock(p_for_mclk_count, clk_audio_mclk);   /* Clock the "count" port from the clock block */
                                                                /* Note, AudioHub() will configure and start the clock */


            par{
                {
                    init_xud_resources(resources);
                    XUD_Main(c_ep_out, 2, c_ep_in, 3, c_sof, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_SELF);
                }

                /* Endpoint 0 core from lib_xua */
                /* Note, since we are not using many features we pass in null for quite a few params.. */
                XUA_Endpoint0(c_ep_out[0], c_ep_in[0], c_aud_ctl, null, null, null, null);

                /* Buffering cores - handles audio data to/from EP's and gives/gets data to/from the audio I/O core */
                /* Note, this spawns two cores */

                XUA_Buffer(c_ep_out[1], c_ep_in[2], c_ep_in[1], c_sof, c_aud_ctl, p_for_mclk_count, c_aud);

                XUA_AudioHub(c_aud, clk_audio_mclk, clk_audio_bclk, p_mclk_in, p_lrclk, p_bclk, p_i2s_dac, p_i2s_adc);
            }
        }

        on I2C_TILE_1: {
            i2c_server_task(c_samp_freq, p_scl, p_sda);
        }


        on AUDIO_TILE_2:{
    
            setup_chanend(c_samp_freq2);
            p_codec_reset2 <: 0xf; // Take out of reset

            set_port_clock(p_for_mclk_count2, clk_audio_mclk2);   /* Clock the "count" port from the clock block */
                                                                /* Note, AudioHub() will configure and start the clock */


            par{
                {
                    init_xud_resources(resources2);
                    XUD_Main_wrapper(c_ep_out2, 2, c_ep_in2, 3, c_sof2, epTypeTableOut2, epTypeTableIn2, XUD_SPEED_HS, XUD_PWR_SELF);
                }

                /* Endpoint 0 core from lib_xua */
                /* Note, since we are not using many features we pass in null for quite a few params.. */
                XUA_Endpoint0_wrapper(c_ep_out2[0], c_ep_in2[0], c_aud_ctl2, null, null, null, null);

                /* Buffering cores - handles audio data to/from EP's and gives/gets data to/from the audio I/O core */
                /* Note, this spawns two cores */

                XUA_Buffer_wrapper(c_ep_out2[1], c_ep_in2[2], c_ep_in2[1], c_sof2, c_aud_ctl2, p_for_mclk_count2, c_aud2);

                XUA_AudioHub_wrapper(c_aud2, clk_audio_mclk2, clk_audio_bclk2, p_mclk_in2, p_lrclk2, p_bclk2, p_i2s_dac2, p_i2s_adc2);
            }
        }

        on I2C_TILE_2: {
            i2c_server_task(c_samp_freq2, p_scl2, p_sda2);
        }

    }
    
    return 0;
}


