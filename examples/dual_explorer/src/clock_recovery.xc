#include <xs1.h>
#include <platform.h>
#include <print.h>
#include <stdio.h>

extern "C"{
#include "sw_pll.h"
}
#include "xc_ptr.h"

#define MCLK_FREQUENCY              24576000
#define REF_FREQUENCY               96000
#define PLL_RATIO                   (MCLK_FREQUENCY / REF_FREQUENCY)
#define CONTROL_LOOP_COUNT          512

#define CONTROL_RATE_HZ             10

#define APP_PLL_CTL_REG 0x0A809200
#define APP_PLL_DIV_REG 0x80000005
#define APP_PLL_FRAC_REG 0x8000040A
#define SW_PLL_SDM_CTRL_MID 478151
#define SW_PLL_SDM_RATE 1000000

//Exists on AUDIO_TILE_1
extern unsigned g_freqChange_sampFreq;
extern in port p_mclk_counter_recovery;

//Exists on AUDIO_TILE_2
extern unsigned g_freqChange_sampFreq_2; 
extern in port p_mclk_counter_recovery2;

uint32_t mclk_from_freq(uint32_t sample_rate)
{
    if( sample_rate == 48000 ||
        sample_rate == 96000 ||
        sample_rate == 192000)
    {
        return 24576000;
    } else {
        return 22579200;
    }
}

void calc_frequency_error(uint32_t sample_rate, uint32_t sample_rate_2, uint16_t mclk_count, uint16_t mclk_count_2)
{
    static uint16_t mclk_count_last = 0;
    static uint16_t mclk_count_last_2 = 0;

    uint32_t mclk_freq = mclk_from_freq(sample_rate);
    uint32_t mclk_freq_2 = mclk_from_freq(sample_rate_2);

    uint32_t expected_mclk_inc_24 = mclk_from_freq(48000) / CONTROL_RATE_HZ;
    uint32_t expected_mclk_inc_22 = mclk_from_freq(44100) / CONTROL_RATE_HZ;

    uint16_t expected_mclk_count = mclk_count_last;
    if(mclk_freq == mclk_from_freq(48000))
    {
        expected_mclk_count += expected_mclk_inc_24;
    } else {
        expected_mclk_count += expected_mclk_inc_22;
    }
    uint16_t expected_mclk_count_2 = mclk_count_last_2;
    if(mclk_freq_2 == mclk_from_freq(48000))
    {
        expected_mclk_count_2 += expected_mclk_inc_24;
    } else {
        expected_mclk_count_2 += expected_mclk_inc_22;
    }


    printf("1: exp: %d act: %d err: %d\n", expected_mclk_count, mclk_count, expected_mclk_count - mclk_count);
    printf("2: exp: %d act: %d err: %d\n", expected_mclk_count_2, mclk_count_2,  expected_mclk_count_2 - mclk_count_2);

    mclk_count_last = mclk_count;  
    mclk_count_last_2 = mclk_count_2;  


}

//Exists on AUDIO_TILE_2
void clock_recovery(chanend c_mclk_sample)
{
    while(1)
    {
        printstr("clock_recovery\n");

        sw_pll_state_t sw_pll;
        sw_pll_sdm_init(&sw_pll,
                    SW_PLL_15Q16(0.0),
                    SW_PLL_15Q16(32.0),
                    SW_PLL_15Q16(0.25),
                    CONTROL_LOOP_COUNT,
                    PLL_RATIO,
                    0, /* No jitter compensation needed */
                    APP_PLL_CTL_REG,
                    APP_PLL_DIV_REG,
                    APP_PLL_FRAC_REG,
                    SW_PLL_SDM_CTRL_MID,
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
                    uint32_t tmp;
                    asm volatile(" getts %0, res[%1]" : "=r" (tmp) : "r" (p_mclk_counter_recovery2));
                    c_mclk_sample <: 0;
                    uint16_t mclk_count;
                    c_mclk_sample :> mclk_count;
                    uint32_t sample_rate;
                    uint16_t mclk_count2 = (uint16_t)tmp;
                    c_mclk_sample :> sample_rate;
                    uint32_t sample_rate_2;
                    GET_SHARED_GLOBAL(sample_rate_2, g_freqChange_sampFreq_2);

                    calc_frequency_error(sample_rate, sample_rate_2, mclk_count, mclk_count2);

                    time_trigger += XS1_TIMER_HZ / CONTROL_RATE_HZ;
                break;
            } // select
        } // mclk_rate_same
    } // while(1)
}


//Exists on AUDIO_TILE_1
void mclk_counter(chanend c_mclk_sample)
{
    while(1)
    {
        select
        {
            case c_mclk_sample :> int _:
                uint16_t u_tmp = 0;
                asm volatile(" getts %0, res[%1]" : "=r" (u_tmp) : "r" (p_mclk_counter_recovery));
                c_mclk_sample <: u_tmp;
                uint32_t sample_rate;
                GET_SHARED_GLOBAL(sample_rate, g_freqChange_sampFreq);
                c_mclk_sample <: sample_rate;
                // printuintln(g_freqChange_sampFreq);
            break;
        }
    }
}