#pragma once

void clock_recovery(in port p_mclk_in_copy, in port p_mclk_in_copy_count, clock clk_mclk_in_copy, in port p_for_mclk_count2_copy, chanend c_sigma_delta);
void sigma_delta_modulator(chanend c_sigma_delta);
