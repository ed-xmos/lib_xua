#include "dual_xua_subs.h"

#define XUA_Buffer_Ep     XUA_Buffer_Ep2
#define fb_clocks     fb_clocks2
#define feedbackValid     feedbackValid2
#define g_speed     g_speed2
#define XUA_Buffer     XUA_Buffer2
#define g_freqChange     g_freqChange2
#define masterClockFreq_ptr     masterClockFreq_ptr2


//Additional manually added defines
#define XUA_Buffer_Decouple     XUA_Buffer_Decouple2
#define aud_from_host_usb_ep    aud_from_host_usb_ep2
#define aud_to_host_usb_ep      aud_to_host_usb_ep2
#define buffer_aud_ctl_chan     buffer_aud_ctl_chan2


#include "../../../../lib_xua/src/core/buffer/ep/ep_buffer.xc"