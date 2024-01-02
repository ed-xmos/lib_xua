#include <xs1.h>
#include <platform.h>
#include <print.h>
#include <stdio.h>

extern "C"{
#include "sw_pll.h"
}
#include "xc_ptr.h"

#define CONTROL_RATE_HZ             100

/* Autogenerated SDM App PLL setup by dco_model.py using 22.5792_1M profile */
/* Input freq: 24000000
   F: 134
   R: 0
   f: 8
   p: 18
   OD: 5
   ACD: 5
*/

#define APP_PLL_CTL_REG_22 0x0A808600
#define APP_PLL_DIV_REG_22 0x80000005
#define APP_PLL_FRAC_REG_22 0x80000812
#define SW_PLL_SDM_CTRL_MID_22 498283
#define SW_PLL_SDM_RATE_22 1000000

/* Autogenerated SDM App PLL setup by dco_model.py using 24.576_1M profile */
/* Input freq: 24000000
   F: 146
   R: 0
   f: 4
   p: 10
   OD: 5
   ACD: 5
*/

#define APP_PLL_CTL_REG_24 0x0A809200
#define APP_PLL_DIV_REG_24 0x80000005
#define APP_PLL_FRAC_REG_24 0x8000040A
#define SW_PLL_SDM_CTRL_MID_24 478151
#define SW_PLL_SDM_RATE_24 1000000


const uint32_t app_pll_ctl_reg[2] = {APP_PLL_CTL_REG_22, APP_PLL_CTL_REG_24};
const uint32_t app_pll_div_reg[2] = {APP_PLL_DIV_REG_22, APP_PLL_DIV_REG_24};
const uint32_t app_pll_frac_reg[2] = {APP_PLL_FRAC_REG_22, APP_PLL_FRAC_REG_24};
const uint32_t sw_pll_sdm_ctrl_mid[2] = {SW_PLL_SDM_CTRL_MID_22, SW_PLL_SDM_CTRL_MID_24};
const uint32_t sw_pll_sdm_rate[2] = {SW_PLL_SDM_RATE_22, SW_PLL_SDM_RATE_24};



//Exists on AUDIO_TILE_2
extern unsigned g_freqChange_sampFreq; 

int32_t mclk_from_freq(uint32_t sample_rate)
{
    if( sample_rate == 48000 ||
        sample_rate == 96000 ||
        sample_rate == 192000)
    {
        return 24576000; // TODO get from XUA
    } else {
        return 22579200; // TODO get from XUA
    }
}

int16_t calc_frequency_error(uint16_t mclk_count, uint16_t mclk_count_2)
{
    static uint16_t mclk_count_last = 0;
    static uint16_t mclk_count_last_2 = 0;

    // Work out what the nominal mclk count increase should be
    const uint16_t expected_mclk_inc_24 = mclk_from_freq(48000) / CONTROL_RATE_HZ;
    const uint16_t expected_mclk_inc_22 = mclk_from_freq(44100) / CONTROL_RATE_HZ;
    // Draw a line to compare to see if mclk read is 22 or 24
    const uint16_t clk_inc_half_24_22 = (expected_mclk_inc_24 + expected_mclk_inc_22) / 2;

    // Work out increment since last time
    uint16_t mclk_count_inc = mclk_count - mclk_count_last;
    uint16_t mclk_count_inc_2 = mclk_count_2 - mclk_count_last_2;

    // Work out which clock we are seeing
    int mclk_is_24m = mclk_count_inc > clk_inc_half_24_22;
    int mclk_2_is_24m = mclk_count_inc_2 > clk_inc_half_24_22;
    
    int16_t f_error = 0;

    // Master is on 24, Slave is on 22
    if(mclk_is_24m && !mclk_2_is_24m)
    {
        f_error = ((int32_t)expected_mclk_inc_24 - (int32_t)mclk_count_inc) - ((int32_t)expected_mclk_inc_22 - (int32_t)mclk_count_inc_2) ;
    }
    // Master is on 22, Slave is on 24
    else if (!mclk_is_24m && mclk_2_is_24m)
    {
        f_error = ((int32_t)expected_mclk_inc_22 - (int32_t)mclk_count_inc) - ((int32_t)expected_mclk_inc_24 - (int32_t)mclk_count_inc_2) ;

    }
    // Both the same so no offsets required
    else {
        f_error = (-(int32_t)mclk_count_inc) - (-(int32_t)mclk_count_inc_2) ;
    }

    // Store for next time
    mclk_count_last = mclk_count;  
    mclk_count_last_2 = mclk_count_2;  

    return f_error;
}

//Exists on AUDIO_TILE_2
void clock_recovery(in port p_mclk_in_copy, in port p_mclk_in_copy_count, clock clk_mclk_in_copy, in port p_for_mclk_count2_copy, chanend c_sigma_delta)
{
    // Setup ports to count remote MCLK
    configure_clock_src(clk_mclk_in_copy, p_mclk_in_copy);
    set_port_clock(p_mclk_in_copy_count, clk_mclk_in_copy);
    start_clock(clk_mclk_in_copy);


    uint32_t old_sample_rate_2 = 48000; // TODO grab from XUA

    // Iterates each time we change sample rate on slave
    while(1)
    {
        printstr("clock_recovery\n");

        const uint32_t mclk_freq = mclk_from_freq(old_sample_rate_2);
        const int pll_reg_idx = mclk_freq == 22579200 ? 0 : 1;

        sw_pll_state_t sw_pll;
        sw_pll_sdm_init(&sw_pll,
                    SW_PLL_15Q16(0.0),
                    SW_PLL_15Q16(32.0),
                    SW_PLL_15Q16(0.25),
                    0, // LOOP COUNT Don't care for this API
                    0, // PLL_RATIO  Don't care for this API
                    0, /* No jitter compensation needed */
                    app_pll_ctl_reg[pll_reg_idx],
                    app_pll_div_reg[pll_reg_idx],
                    app_pll_frac_reg[pll_reg_idx],
                    sw_pll_sdm_ctrl_mid[pll_reg_idx],
                    3000 /*PPM_RANGE FOR PFD*/);

        printstr("sw_pll init'd\n");

        timer tmr;
        int time_trigger;
        tmr :> time_trigger;

        int mclk_rate_same = 1;

        while(mclk_rate_same)
        {

            select
            {
                case tmr when timerafter(time_trigger) :> int _:
                    uint16_t mclk_count, mclk_count_2;
                    asm volatile(" getts %0, res[%1]" : "=r" (mclk_count) : "r" (p_mclk_in_copy_count));
                    asm volatile(" getts %0, res[%1]" : "=r" (mclk_count_2) : "r" (p_for_mclk_count2_copy));
                
                    // Grab SR from USB audio stack
                    uint32_t sample_rate_2;
                    GET_SHARED_GLOBAL(sample_rate_2, g_freqChange_sampFreq);

                    int16_t f_error = calc_frequency_error(mclk_count, mclk_count_2);

                    printintln(f_error);

                    if(sample_rate_2 != old_sample_rate_2)
                    {
                        outuint(c_sigma_delta, 0); // Signal to stop writing to frac reg
                        old_sample_rate_2 = sample_rate_2;
                        mclk_rate_same = 0;
                        break;
                    }

                    sw_pll_sdm_do_control_from_error(&sw_pll, -f_error);
                    int32_t dco_control = sw_pll.sdm_state.current_ctrl_val;
                    outuint(c_sigma_delta, dco_control);

                    printintln(dco_control);

                    time_trigger += XS1_TIMER_HZ / CONTROL_RATE_HZ;
                break;
            } // select
        } // mclk_rate_same
    } // while(1)
}

//Exists on I2C_TILE_2
void sigma_delta_modulator(chanend c_sigma_delta)
{
    printf("sdm_task\n");

    while(1)
    {

        const uint32_t sdm_interval = XS1_TIMER_HZ / sw_pll_sdm_rate[0]; // in 10ns ticks = 1MHz

        sw_pll_sdm_state_t sdm_state;
        sw_pll_init_sigma_delta(&sdm_state);

        tileref_t this_tile = get_local_tile_id();

        timer tmr;
        int32_t time_trigger;
        tmr :> time_trigger;

        int running = true;
        int32_t sdm_in = 0; // Zero is an invalid number and the SDM will not write the frac reg until 
                            // the first control value has been received. This avoids issues with 
                            // channel lockup if two tasks (eg. init and SDM) try to write at the same 
                            // time. 

        while(running)
        {
            // Poll for new SDM control value
            unsigned tmp;
            select
            {
                case inuint_byref(c_sigma_delta, tmp):
                    sdm_in = (int32_t)tmp;
                break;

                // Do nothing & fall-through
                default:
                break;
            }

            // Wait until the timer value has been reached
            // This implements a timing barrier and keeps
            // the loop rate constant.
            select{
                case tmr when timerafter(time_trigger) :> int _:
                    time_trigger += sdm_interval;
                break;
            }

            // Do not write to the frac reg until we get out first
            // control value. This will avoid the writing of the
            // frac reg from two different threads which may cause
            // a channel deadlock.
            if(sdm_in){
                sw_pll_do_sigma_delta(&sdm_state, this_tile, sdm_in);
            }
        } // running
    }// while 1
}

