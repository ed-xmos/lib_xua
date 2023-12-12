#include <xs1.h>
#include "xua.h"


void UserBufferManagementInit(unsigned samFreq)
{
    printstr("UserBufferManagementInit ");printuintln(samFreq);
    printstr("Tile: 0x");printhexln(get_local_tile_id());
}

static unsafe chanend c_bridge_glob = null;
static unsigned g_num_in = 0;
static unsigned g_num_out = 0;
unsafe{
    unsigned * unsafe g_num_in_ptr = &g_num_in;
    unsigned * unsafe g_num_out_ptr = &g_num_out;
}

void setup_bridge_uac_side(chanend c_bridge, unsigned num_in, unsigned num_out){
    unsafe{
        c_bridge_glob = c_bridge;
        *g_num_in_ptr = num_in;
        *g_num_out_ptr = num_out;
    }
}


void UserBufferManagement(unsigned sampsFromUsbToAudio[], unsigned sampsFromAudioToUsb[])
{
    // printintln(sampsFromUsbToAudio[0]);
    unsafe{
        for(int i = 0; i < g_num_out; i++)
        {
            sampsFromAudioToUsb[i] = inuint((chanend)c_bridge_glob);
        }
        for(int i = 0; i < g_num_in; i++)
        {
            outuint((chanend)c_bridge_glob, sampsFromUsbToAudio[i]);
        }
    }
}

#define NUM_CHANS_H2D   2
#define NUM_CHANS_H2D2  2
#define NUM_CHANS_D2H   2
#define NUM_CHANS_D2H2  2

void bridge_task(chanend c_bridge, chanend c_bridge2)
{
    printstr("bridge_task\n");

    unsigned samps_h2d[2] = {0};
    unsigned samps_h2d2[2] = {0};

    unsigned samps_d2h[2] = {0};
    unsigned samps_d2h2[2] = {0};

    // Pre-load bridge to UAC direction
    for(int i = 0; i < NUM_CHANS_D2H; i++)
    {
        outuint(c_bridge, samps_d2h[i]);
    }

    for(int i = 0; i < NUM_CHANS_D2H2; i++)
    {
        outuint(c_bridge2,  samps_d2h2[i]);
    }

    unsigned host_counter = 0;
    unsigned host_counter2 = 0;

    while(1)
    {
        select 
        {
            case inuint_byref(c_bridge, samps_h2d[0]):
                for(int i = 1; i < NUM_CHANS_H2D; i++)
                {
                    samps_h2d[i] = inuint(c_bridge);
                }

                for(int i = 0; i < NUM_CHANS_D2H; i++)
                {
                    outuint(c_bridge, samps_d2h[i]);
                }

                host_counter++;
                if(host_counter > 10000)
                {
                    printchar('.');
                    host_counter = 0;
                }
            break;

            case inuint_byref(c_bridge2, samps_h2d2[0]):
                for(int i = 1; i < NUM_CHANS_H2D2; i++)
                {
                    samps_h2d2[i] = inuint(c_bridge2);
                }

                for(int i = 0; i < NUM_CHANS_D2H2; i++)
                {
                    outuint(c_bridge2, samps_d2h2[i]);
                }

                host_counter2++;
                if(host_counter2 > 10000)
                {
                    printchar('+');
                    host_counter2 = 0;
                }
            break;

        }
    }
}