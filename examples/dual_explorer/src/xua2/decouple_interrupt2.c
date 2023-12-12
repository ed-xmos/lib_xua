#include "dual_xua_subs.h"


// #include "../../../../lib_xua/src/core/buffer/decouple/decouple_interrupt.c"

// Copyright 2015-2021 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include "xua.h"
#if XUA_USB_EN
#include "interrupt.h"

register_interrupt_handler(handle_audio_request2, 1, 200)
#endif
