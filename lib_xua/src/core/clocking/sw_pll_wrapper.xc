// Copyright 2024 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <xs1.h>
#include <assert.h>
#include <print.h>

#include "sw_pll_wrapper.h"
#include "xua.h"

#if USE_SW_PLL


{unsigned, unsigned} init_sw_pll(sw_pll_state_t &sw_pll, unsigned mClk)
{
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

    const int clkIndex = mClk == MCLK_48 ? 1 : 0;

    sw_pll_sdm_init(&sw_pll,
                SW_PLL_15Q16(0.0),
                SW_PLL_15Q16(32.0),
                SW_PLL_15Q16(0.25),
                0, /* LOOP COUNT Don't care for this API */
                0, /* PLL_RATIO  Don't care for this API */
                0, /* No jitter compensation needed */
                app_pll_ctl_reg[clkIndex],
                app_pll_div_reg[clkIndex],
                app_pll_frac_reg[clkIndex],
                sw_pll_sdm_ctrl_mid[clkIndex],
                3000 /* PPM_RANGE (FOR PFD) Don't care for this API*/ );

    /* Reset SDM too */
    sw_pll_init_sigma_delta(&sw_pll.sdm_state);

    return {XS1_TIMER_HZ / sw_pll_sdm_rate[clkIndex], sw_pll_sdm_ctrl_mid[clkIndex]};
}

void do_sw_pll_phase_frequency_detector_dig_rx( unsigned short mclk_time_stamp,
                                                unsigned mclks_per_sample,
                                                chanend c_sw_pll,
                                                int receivedSamples,
                                                int &reset_sw_pll_pfd)
{
    const unsigned control_loop_rate_divider = 6; /* 300Hz * 2 edges / 6 -> 100Hz loop rate */
    static unsigned control_loop_counter = 0;
    static unsigned total_received_samples = 0;

    /* Keep a store of the last mclk time stamp so we can work out the increment */
    static unsigned short last_mclk_time_stamp = 0;

    control_loop_counter++;

    total_received_samples += receivedSamples;

    if(control_loop_counter == control_loop_rate_divider)
    {
        /* Calculate what the zero-error mclk count increment should be for this many samples */
        const unsigned expected_mclk_inc = mclks_per_sample * total_received_samples / 2; /* divide by 2 because this fn is called per edge */

        /* Calculate actualy time-stamped mclk count increment is */
        const unsigned short actual_mclk_inc = mclk_time_stamp - last_mclk_time_stamp;

        /* The difference is the raw error in terms of mclk counts */
        short f_error = (int)actual_mclk_inc - (int)expected_mclk_inc;
        if(reset_sw_pll_pfd)
        {
            f_error = 0;            /* Skip first measurement as it will likely be very out */
            reset_sw_pll_pfd = 0;
        }

        /* send PFD output to the sigma delta thread */
        outuint(c_sw_pll, (int) f_error);
     
        last_mclk_time_stamp = mclk_time_stamp;
        control_loop_counter = 0;
        total_received_samples = 0;
    }
}

void sw_pll_task(chanend c_sw_pll){
    /* Zero is an invalid number and the SDM will not write the frac reg until
       the first control value has been received. This avoids issues with 
       channel lockup if two tasks (eg. init and SDM) try to write at the same time. */ 

    while(1)
    {
        unsigned selected_mclk_rate = inuint(c_sw_pll);

        int f_error = 0;
        int dco_setting = 0;        /* gets set at init_sw_pll */
        unsigned sdm_interval = 0;  /* gets set at init_sw_pll */
        sw_pll_state_t sw_pll;

        /* initialse the SDM and gather SDM initial settings */
        {sdm_interval, dco_setting} = init_sw_pll(sw_pll, selected_mclk_rate);

        tileref_t this_tile = get_local_tile_id();

        timer tmr;
        int32_t time_trigger;
        tmr :> time_trigger;
        int running = 1;

        outuint(c_sw_pll, 0); /* Signal back via clockgen to audio to start I2S */

        unsigned rx_word = 0;
        while(running)
        {
            /* Poll for new SDM control value */
            select
            {
                case inuint_byref(c_sw_pll, rx_word):
                    if(rx_word == DISABLE_SDM)
                    {
                        f_error = 0;
                        running = 0;
                    }
                    else
                    {
                        f_error = (int32_t)rx_word;
                        unsafe
                        {
                            sw_pll_sdm_do_control_from_error(&sw_pll, -f_error);
                            dco_setting = sw_pll.sdm_state.current_ctrl_val;
                        }
                    }
                break;

                /* Do nothing & fall-through. Above case polls only once per loop */
                default:
                break;
            }

            /* Wait until the timer value has been reached
               This implements a timing barrier and keeps
               the loop rate constant. */
            select
            {
                case tmr when timerafter(time_trigger) :> int _:
                    time_trigger += sdm_interval;
                break;
            }

            unsafe {
                sw_pll_do_sigma_delta(&sw_pll.sdm_state, this_tile, dco_setting);
            }
        } /* if running */
    } /* while(1) */
}


void restart_sigma_delta(chanend c_sw_pll, unsigned selected_mclk_rate)
{
    outuint(c_sw_pll, DISABLE_SDM); /* Resets SDM */
    outuint(c_sw_pll, selected_mclk_rate);
}

#endif /* USE_SW_PLL */
