#include <xs1.h>
#include <string.h>
#include <stdint.h>
#include "xua.h"

static timer tmr;
static int32_t time_trigger = 0;

void UserBufferManagementInit(unsigned samFreq)
{
    printstr("UserBufferManagementInit ");printuintln(samFreq);
    printstr("Tile: 0x");printhexln(get_local_tile_id());

    tmr :> time_trigger;
}

// These are used by different tiles (different address space) so
// are independent
static unsafe chanend c_bridge_glob = null;
static unsigned g_num_in = 0;
static unsigned g_num_out = 0;
static unsigned g_usb_rate = 0;
unsafe{
    unsigned * unsafe g_num_in_ptr = &g_num_in;
    unsigned * unsafe g_num_out_ptr = &g_num_out;
    unsigned * unsafe g_usb_rate_ptr = &g_usb_rate;
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
    static unsigned counter = 0;
    int32_t time_now;
    tmr :> time_now;

    unsafe{
        for(int i = 0; i < g_num_out; i++)
        {
            sampsFromAudioToUsb[i] = inuint((chanend)c_bridge_glob);
        }
        for(int i = 0; i < g_num_in; i++)
        {
            outuint((chanend)c_bridge_glob, sampsFromUsbToAudio[i]);
        }
        outuint((chanend)c_bridge_glob, *g_usb_rate_ptr);
    }

    if (timeafter(time_now, time_trigger))
    {
        g_usb_rate = counter;
        time_trigger += XS1_TIMER_HZ;
        counter = 0;
    } else {
        counter++;
    }

}

#define NUM_CHANS_H2D   2
#define NUM_CHANS_H2D2  2
#define NUM_CHANS_D2H   2
#define NUM_CHANS_D2H2  2

// We get 48 bytes of buffering between tiles on-chip
// and 110 bytes of buffering between nodes so that
// is plenty to handle a few ints with blocking 
void bridge_task(chanend c_bridge, chanend c_bridge2)
{
    printstr("bridge_task\n");

    timer tmr;
    int32_t time_trigger;
    tmr :> time_trigger;


    unsigned samps_h2d[NUM_CHANS_H2D] = {0};
    unsigned samps_h2d2[NUM_CHANS_H2D2] = {0};

    unsigned samps_d2h[NUM_CHANS_D2H] = {0};
    unsigned samps_d2h2[NUM_CHANS_D2H2] = {0};

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

    unsigned usb_rate = 0;
    unsigned usb_rate2 = 0;

    while(1)
    {
        select 
        {
            // Exchange with USB host 1
            case inuint_byref(c_bridge, samps_h2d[0]):
                for(int i = 1; i < NUM_CHANS_H2D; i++)
                {
                    samps_h2d[i] = inuint(c_bridge);
                }

                usb_rate = inuint(c_bridge);

                for(int i = 0; i < NUM_CHANS_D2H; i++)
                {
                    outuint(c_bridge, samps_d2h[i]);
                }

                memcpy(samps_d2h2, samps_h2d, 2 * sizeof(unsigned)); //Copy playing samples to recording samples on other I/F

                host_counter++;
                if(host_counter > 10000)
                {
                    printchar('.');
                    host_counter = 0;
                }
            break;

            // Exchange with USB host 2
            case inuint_byref(c_bridge2, samps_h2d2[0]):
                for(int i = 1; i < NUM_CHANS_H2D2; i++)
                {
                    samps_h2d2[i] = inuint(c_bridge2);
                }

                usb_rate2 = inuint(c_bridge2);

                for(int i = 0; i < NUM_CHANS_D2H2; i++)
                {
                    outuint(c_bridge2, samps_d2h2[i]);
                }

                memcpy(samps_d2h, samps_h2d2, 2 * sizeof(unsigned)); //Copy playing samples to recording samples on other I/F

                host_counter2++;
                if(host_counter2 > 10000)
                {
                    printchar('+');
                    host_counter2 = 0;
                }
            break;

            case tmr when timerafter(time_trigger) :> int _:
                printintln(usb_rate);
                printintln(usb_rate2);

                time_trigger += XS1_TIMER_HZ;
            break;
        }
    }
}