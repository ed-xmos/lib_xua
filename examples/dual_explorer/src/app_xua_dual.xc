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
#include "xud_device.h"
#include "AudioConfig.h"

#define AUDIO_TILE_1    tile[1]
#define AUDIO_TILE_2    tile[3]

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


int main()
{
    /* Channels for lib_xud */
    chan c_ep_out[2];
    chan c_ep_in[3];

    /* Channel for communicating SOF notifications from XUD to the Buffering cores */
    chan c_sof;

    /* Channel for audio data between buffering cores and AudioHub/IO core */
    chan c_aud;
    
    /* Channel for communicating control messages from EP0 to the rest of the device (via the buffering cores) */
    chan c_aud_ctl;


    chan c_samp_freq;
    par
    {
        /* Low level USB device layer core */ 
        on tile[1]:{
    
            setup_chanend(c_samp_freq);
            p_codec_reset <: 0xf; // Take out of reset

            set_port_clock(p_for_mclk_count, clk_audio_mclk);   /* Clock the "count" port from the clock block */
                                                                /* Note, AudioHub() will configure and start the clock */


            par{
                XUD_Main(c_ep_out, 2, c_ep_in, 3, c_sof, epTypeTableOut, epTypeTableIn, XUD_SPEED_HS, XUD_PWR_SELF);

                /* Endpoint 0 core from lib_xua */
                /* Note, since we are not using many features we pass in null for quite a few params.. */
                XUA_Endpoint0(c_ep_out[0], c_ep_in[0], c_aud_ctl, null, null, null, null);

                /* Buffering cores - handles audio data to/from EP's and gives/gets data to/from the audio I/O core */
                /* Note, this spawns two cores */

                XUA_Buffer(c_ep_out[1], c_ep_in[2], c_ep_in[1], c_sof, c_aud_ctl, p_for_mclk_count, c_aud);

                XUA_AudioHub(c_aud, clk_audio_mclk, clk_audio_bclk, p_mclk_in, p_lrclk, p_bclk, p_i2s_dac, p_i2s_adc);
            }
        }

        on tile[0]: {
            i2c_server_task(c_samp_freq);
        }
    }
    
    return 0;
}


