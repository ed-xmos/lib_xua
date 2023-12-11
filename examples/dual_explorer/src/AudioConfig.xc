#include <xs1.h>
#include <platform.h>
#include <print.h>
#include <stdio.h>
#include <assert.h>

#include "xua_conf.h"
#include "i2c.h"


// TLV320AIC3204 Device I2C Address
#define AIC3204_I2C_DEVICE_ADDR 0x18

// TLV320AIC3204 Register Addresses
// Page 0
#define AIC3204_PAGE_CTRL     0x00 // Register 0  - Page Control
#define AIC3204_SW_RST        0x01 // Register 1  - Software Reset
#define AIC3204_NDAC          0x0B // Register 11 - NDAC Divider Value
#define AIC3204_MDAC          0x0C // Register 12 - MDAC Divider Value
#define AIC3204_DOSR          0x0E // Register 14 - DOSR Divider Value (LS Byte)
#define AIC3204_NADC          0x12 // Register 18 - NADC Divider Value
#define AIC3204_MADC          0x13 // Register 19 - MADC Divider Value
#define AIC3204_AOSR          0x14 // Register 20 - AOSR Divider Value
#define AIC3204_CODEC_IF      0x1B // Register 27 - CODEC Interface Control
#define AIC3204_DAC_SIG_PROC  0x3C // Register 60 - DAC Sig Processing Block Control
#define AIC3204_ADC_SIG_PROC  0x3D // Register 61 - ADC Sig Processing Block Control
#define AIC3204_DAC_CH_SET1   0x3F // Register 63 - DAC Channel Setup 1
#define AIC3204_DAC_CH_SET2   0x40 // Register 64 - DAC Channel Setup 2
#define AIC3204_DACL_VOL_D    0x41 // Register 65 - DAC Left Digital Vol Control
#define AIC3204_DACR_VOL_D    0x42 // Register 66 - DAC Right Digital Vol Control
#define AIC3204_ADC_CH_SET    0x51 // Register 81 - ADC Channel Setup
#define AIC3204_ADC_FGA_MUTE  0x52 // Register 82 - ADC Fine Gain Adjust/Mute

// Page 1
#define AIC3204_PWR_CFG       0x01 // Register 1  - Power Config
#define AIC3204_LDO_CTRL      0x02 // Register 2  - LDO Control
#define AIC3204_PLAY_CFG1     0x03 // Register 3  - Playback Config 1
#define AIC3204_PLAY_CFG2     0x04 // Register 4  - Playback Config 2
#define AIC3204_OP_PWR_CTRL   0x09 // Register 9  - Output Driver Power Control
#define AIC3204_CM_CTRL       0x0A // Register 10 - Common Mode Control
#define AIC3204_HPL_ROUTE     0x0C // Register 12 - HPL Routing Select
#define AIC3204_HPR_ROUTE     0x0D // Register 13 - HPR Routing Select
#define AIC3204_HPL_GAIN      0x10 // Register 16 - HPL Driver Gain
#define AIC3204_HPR_GAIN      0x11 // Register 17 - HPR Driver Gain
#define AIC3204_HP_START      0x14 // Register 20 - Headphone Driver Startup
#define AIC3204_LPGA_P_ROUTE  0x34 // Register 52 - Left PGA Positive Input Route
#define AIC3204_LPGA_N_ROUTE  0x36 // Register 54 - Left PGA Negative Input Route
#define AIC3204_RPGA_P_ROUTE  0x37 // Register 55 - Right PGA Positive Input Route
#define AIC3204_RPGA_N_ROUTE  0x39 // Register 57 - Right PGA Negative Input Route
#define AIC3204_LPGA_VOL      0x3B // Register 59 - Left PGA Volume
#define AIC3204_RPGA_VOL      0x3C // Register 60 - Right PGA Volume
#define AIC3204_ADC_PTM       0x3D // Register 61 - ADC Power Tune Config
#define AIC3204_AN_IN_CHRG    0x47 // Register 71 - Analog Input Quick Charging Config
#define AIC3204_REF_STARTUP   0x7B // Register 123 - Reference Power Up Config

// TLV320AIC3204 easy register access defines
#define AIC3204_REGREAD(reg, data)  {data[0] = i_i2c[0].read_reg(AIC3204_I2C_DEVICE_ADDR, reg, result);}
#define AIC3204_REGWRITE(reg, data) {result = i_i2c[0].write_reg(AIC3204_I2C_DEVICE_ADDR, reg, data);}



// 24MHz in, 24.576MHz out, integer mode
// Found exact solution:   IN  24000000.0, OUT  24576000.0, VCO 2457600000.0, RD  5, FD  512, OD 10, FOD  10
// 24MHz in, 22.5792MHz out, frac mode
// Found exact solution: IN 24000000.0, OUT 22579200.0, VCO 2257920000.0, RD 5, FD 470.400 (m = 2, n = 5), OD 5, FOD 10
void SetupPll(unsigned mclk)
{
    printf("SetupPll: %u\n", mclk);
                                   //DISABLE,  APP_PLL_CTL, APP_PLL_DIV, APP_PLL_FRAC
    unsigned pll_settings_441[] = {0x0201D504, 0x0A01D504, 0x80000004, 0x80000104};
    unsigned pll_settings_48[]  = {0x0201FF04, 0x0A01FF04, 0x80000004, 0x00000000};

    unsigned *settings_ptr; 
    switch(mclk){
        case MCLK_48:
            settings_ptr = pll_settings_48;
        break;
        case MCLK_441:
            settings_ptr = pll_settings_441;
        break;
        default:
            assert(0);
        break;
    }                


    write_sswitch_reg(get_local_tile_id(), XS1_SSWITCH_SS_APP_PLL_CTL_NUM,            settings_ptr[0]);
    delay_milliseconds(1);
    write_sswitch_reg(get_local_tile_id(), XS1_SSWITCH_SS_APP_PLL_CTL_NUM,            settings_ptr[1]);
    write_sswitch_reg(get_local_tile_id(), XS1_SSWITCH_SS_APP_PLL_CTL_NUM,            settings_ptr[1]);
    write_sswitch_reg(get_local_tile_id(), XS1_SSWITCH_SS_APP_PLL_FRAC_N_DIVIDER_NUM, settings_ptr[3]);
    write_sswitch_reg(get_local_tile_id(), XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM,        settings_ptr[2]);
    delay_milliseconds(1);
}


/* Configures master clock and codec to desired sample freq*/
void ConfigCodec(unsigned samFreq, port p_scl, port p_sda)  
{
    interface i2c_master_if i_i2c[1];

    par{
        [[distribute]] i2c_master(i_i2c, 1, p_scl, p_sda, 100);
        {
            unsigned char data[1] = {0};
            unsigned char tmp[1] = {0};
            i2c_regop_res_t result;

            // Check we can talk to the CODEC
            AIC3204_REGREAD(0, tmp);
            if (tmp[0] != 0)
            {
                printstr("DAC Reg Read Problem?\n");
            }

            // Set register page to 0
            AIC3204_REGWRITE(AIC3204_PAGE_CTRL, 0x00);

            // Initiate SW reset (PLL is powered off as part of reset)
            AIC3204_REGWRITE(AIC3204_SW_RST, 0x01);

            // Program clock settings

            // Default is CODEC_CLKIN is from MCLK pin. Don't need to change this.
            // Power up NDAC and set to 1
            AIC3204_REGWRITE(AIC3204_NDAC, 0x81);
            // Power up MDAC and set to 4
            AIC3204_REGWRITE(AIC3204_MDAC, 0x84);
            // Power up NADC and set to 1
            AIC3204_REGWRITE(AIC3204_NADC, 0x81);
            // Power up MADC and set to 4
            AIC3204_REGWRITE(AIC3204_MADC, 0x84);
            // Program DOSR = 128
            AIC3204_REGWRITE(AIC3204_DOSR, 0x80);
            // Program AOSR = 128
            AIC3204_REGWRITE(AIC3204_AOSR, 0x80);
            // Set Audio Interface Config: I2S, 24 bits, slave mode, DOUT always driving.
            AIC3204_REGWRITE(AIC3204_CODEC_IF, 0x20);
            // Program the DAC processing block to be used - PRB_P1
            AIC3204_REGWRITE(AIC3204_DAC_SIG_PROC, 0x01);
            // Program the ADC processing block to be used - PRB_R1
            AIC3204_REGWRITE(AIC3204_ADC_SIG_PROC, 0x01);
            // Select Page 1
            AIC3204_REGWRITE(AIC3204_PAGE_CTRL, 0x01);
            // Enable the internal AVDD_LDO:
            AIC3204_REGWRITE(AIC3204_LDO_CTRL, 0x09);
            //
            // Program Analog Blocks
            // ---------------------
            //
            // Disable Internal Crude AVdd in presence of external AVdd supply or before powering up internal AVdd LDO
            AIC3204_REGWRITE(AIC3204_PWR_CFG, 0x08);
            // Enable Master Analog Power Control
            AIC3204_REGWRITE(AIC3204_LDO_CTRL, 0x01);
            // Set Common Mode voltages: Full Chip CM to 0.9V and Output Common Mode for Headphone to 1.65V and HP powered from LDOin @ 3.3V.
            AIC3204_REGWRITE(AIC3204_CM_CTRL, 0x33);
            // Set PowerTune Modes
            // Set the Left & Right DAC PowerTune mode to PTM_P3/4. Use Class-AB driver.
            AIC3204_REGWRITE(AIC3204_PLAY_CFG1, 0x00);
            AIC3204_REGWRITE(AIC3204_PLAY_CFG2, 0x00);
            // Set ADC PowerTune mode PTM_R4.
            AIC3204_REGWRITE(AIC3204_ADC_PTM, 0x00);
            // Set MicPGA startup delay to 3.1ms
            AIC3204_REGWRITE(AIC3204_AN_IN_CHRG, 0x31);
            // Set the REF charging time to 40ms
            AIC3204_REGWRITE(AIC3204_REF_STARTUP, 0x01);
            // HP soft stepping settings for optimal pop performance at power up
            // Rpop used is 6k with N = 6 and soft step = 20usec. This should work with 47uF coupling
            // capacitor. Can try N=5,6 or 7 time constants as well. Trade-off delay vs “pop” sound.
            AIC3204_REGWRITE(AIC3204_HP_START, 0x25);
            // Route Left DAC to HPL
            AIC3204_REGWRITE(AIC3204_HPL_ROUTE, 0x08);
            // Route Right DAC to HPR
            AIC3204_REGWRITE(AIC3204_HPR_ROUTE, 0x08);
            // We are using Line input with low gain for PGA so can use 40k input R but lets stick to 20k for now.
            // Route IN2_L to LEFT_P with 20K input impedance
            AIC3204_REGWRITE(AIC3204_LPGA_P_ROUTE, 0x20);
            // Route IN2_R to LEFT_M with 20K input impedance
            AIC3204_REGWRITE(AIC3204_LPGA_N_ROUTE, 0x20);
            // Route IN1_R to RIGHT_P with 20K input impedance
            AIC3204_REGWRITE(AIC3204_RPGA_P_ROUTE, 0x80);
            // Route IN1_L to RIGHT_M with 20K input impedance
            AIC3204_REGWRITE(AIC3204_RPGA_N_ROUTE, 0x20);
            // Unmute HPL and set gain to 0dB
            AIC3204_REGWRITE(AIC3204_HPL_GAIN, 0x00);
            // Unmute HPR and set gain to 0dB
            AIC3204_REGWRITE(AIC3204_HPR_GAIN, 0x00);
            // Unmute Left MICPGA, Set Gain to 0dB.
            AIC3204_REGWRITE(AIC3204_LPGA_VOL, 0x00);
            // Unmute Right MICPGA, Set Gain to 0dB.
            AIC3204_REGWRITE(AIC3204_RPGA_VOL, 0x00);
            // Power up HPL and HPR drivers
            AIC3204_REGWRITE(AIC3204_OP_PWR_CTRL, 0x30);

            // Wait for 0.25 sec for soft stepping to take effect
            delay_milliseconds(250);

            //
            // Power Up DAC/ADC
            // ----------------
            //
            // Select Page 0
            AIC3204_REGWRITE(AIC3204_PAGE_CTRL, 0x00);
            // Power up the Left and Right DAC Channels. Route Left data to Left DAC and Right data to Right DAC.
            // DAC Vol control soft step 1 step per DAC word clock.
            AIC3204_REGWRITE(AIC3204_DAC_CH_SET1, 0xd4);
            // Power up Left and Right ADC Channels, ADC vol ctrl soft step 1 step per ADC word clock.
            AIC3204_REGWRITE(AIC3204_ADC_CH_SET, 0xc0);
            // Unmute Left and Right DAC digital volume control
            AIC3204_REGWRITE(AIC3204_DAC_CH_SET2, 0x00);
            // Unmute Left and Right ADC Digital Volume Control.
            AIC3204_REGWRITE(AIC3204_ADC_FGA_MUTE, 0x00);

            delay_milliseconds(1);


            i_i2c[0].shutdown();
        }
    }

    printstr("Sampling Freq = ");
    printintln(samFreq);

}


void i2c_server_task(chanend c_sr_change, port p_scl, port p_sda)
{
    while(1)
    {
        unsigned samFreq;
        c_sr_change :> samFreq;

        ConfigCodec(samFreq, p_scl, p_sda);
    }
}
