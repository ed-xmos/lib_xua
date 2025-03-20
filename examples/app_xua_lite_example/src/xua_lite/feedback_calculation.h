// Copyright 2019-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#ifndef _FEEDBACK_CALCULATION_H_
#define _FEEDBACK_CALCULATION_H_

//USB Asynch mode helper
void do_feedback_calculation(
        unsigned &sof_count,
        const unsigned mclk_hz,
        unsigned mclk_port_counter,
        unsigned &mclk_port_counter_old,
        long long &feedback_value,
        unsigned &mod_from_last_time,
        unsigned fb_clocks[1]
);

#endif // _FEEDBACK_CALCULATION_H_
