#pragma once

void clock_recovery(chanend c_mclk_sample, chanend sigma_delta);
void mclk_counter(chanend c_mclk_sample);
void sigma_delta_modulator(chanend c_sigma_delta);
