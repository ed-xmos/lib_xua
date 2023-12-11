#ifndef _AUDIO_CONFIG_
#define _AUDIO_CONFIG_

void SetupPll(unsigned mclk);

/* Configures master clock and codc for passed sample freq */
void ConfigCodec(unsigned samFeq);

void i2c_server_task(chanend c_samp_freq, port p_scl, port p_sda);
void setup_chanend(chanend c_samp_freq);


#endif
