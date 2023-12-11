#include <xs1.h>
#include <platform.h>
#include <print.h>
#include <stdio.h>
#include "xua_conf.h"
#include <assert.h>

// I2C ports

// on tile[0]: struct r_i2c i2c = {PORT_I2C_SCL, PORT_I2C_SDA};

// GPIO ports
// out port p_led      = PORT_LEDS;
// in port p_buttons   = PORT_BUTTONS;


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
#define AIC3204_REGREAD(reg, data)  {data[0] = 0xAA; i2c_master_read_reg(AIC3204_I2C_DEVICE_ADDR, reg, data, 1, i2c);}
#define AIC3204_REGWRITE(reg, val) {data[0] = val; i2c_master_write_reg(AIC3204_I2C_DEVICE_ADDR, reg, data, 1, i2c);}



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

    write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_PLL_CTL_NUM,            settings_ptr[0]);
    delay_milliseconds(1);
    write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_PLL_CTL_NUM,            settings_ptr[1]);
    write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_PLL_CTL_NUM,            settings_ptr[1]);
    write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_PLL_FRAC_N_DIVIDER_NUM, settings_ptr[3]);
    write_node_config_reg(tile[0], XS1_SSWITCH_SS_APP_CLK_DIVIDER_NUM,        settings_ptr[2]);
    delay_milliseconds(1);
}


/* Configures master clock and codec to desired sample freq*/
void ConfigCodec(unsigned samFreq)  
{
 

}


void i2c_server(chanend c_samp_freq){
    // timer t;
    // unsigned timer_trig;
    // const unsigned led_delay_ticks = XS1_TIMER_KHZ * 100; //100ms
    // t :> timer_trig;
    // timer_trig += led_delay_ticks;
    // unsigned led_port_val = 0x8;

    // while(1){
    //     select{
    //         case c_samp_freq :> unsigned samFreq:
    //             ConfigCodec(samFreq);
    //         break;

    //         case t when timerafter(timer_trig) :> unsigned _:
    //             led_port_val >>= 1;
    //             if(led_port_val == 0){
    //                 led_port_val = 0x8;
    //             }
    //             p_led <: led_port_val;
    //             timer_trig += led_delay_ticks;
    //         break;
    //     }            
    // }
}

