// Copyright 2019-2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.
#include <stdint.h>
#include <limits.h>
#include <xs1.h>
#include <print.h>

#if XUA_LITE_USB_EN

#include "xua_commands.h"
#include "xud.h"
#include "testct_byref.h"
#define DEBUG_UNIT XUA_LITE_BUFFER
#define DEBUG_PRINT_ENABLE_XUA_LITE_BUFFER 1
#include "debug_print.h"

#include "xua.h"
#include "xua_usb_params_funcs.h"
#include "xua_buffer_pack.h"
#include "feedback_calculation.h"

#if defined (STREAM_FORMAT_INPUT_1_RESOLUTION_BITS) && defined (STREAM_FORMAT_OUTPUT_1_RESOLUTION_BITS)
  #include "fifo_impl.h"
  #define BYTES_PER_32B_WORD 4
#else
  #error "No default bit resolution - support 16/24/32 bits"
#endif

#include "xua_buffer_lite.h"


#if ( 0 < HID_CONTROLS )
#include "xua_hid_report.h"
#include "user_hid.h"
#include "xua_hid.h"
#endif

extern XUD_ep ep0_out;
extern XUD_ep ep0_in;

extern port p_sda;

extern uint32_t get_i2s_rate();

static unsigned g_input_interface_num = 0;
static unsigned g_output_interface_num = 0;

extern unsigned int multOut[NUM_USB_CHAN_OUT + 1];
extern unsigned int multIn[NUM_USB_CHAN_IN + 1];

void UserAudioInputStreamStart() {
  g_input_interface_num = 1;
  debug_printf("input_interface_num: %d\n", g_input_interface_num);
}

void UserAudioInputStreamStop() {
  g_input_interface_num = 0;
  debug_printf("input_interface_num: %d\n", g_input_interface_num);
}

void UserAudioOutputStreamStart() {
  g_output_interface_num = 1;
  debug_printf("output_interface_num: %d\n", g_output_interface_num);
}

void UserAudioOutputStreamStop() {
  g_output_interface_num = 0;
  debug_printf("output_interface_num: %d\n", g_output_interface_num);
}


static inline void XUA_transfer_samples(chanend c_audio,
                                        unsigned sampsFromUsbToAudio[],
                                        unsigned sampsFromAudioToUsb[]){
  for(int i = 0; i < NUM_USB_CHAN_OUT; i++){
    outuint(c_audio, sampsFromUsbToAudio[i]);
  }
  for(int i = 0; i < NUM_USB_CHAN_IN; i++){
    int sample = inuint(c_audio);
    sampsFromAudioToUsb[i] = sample;
  }
}


//Unsafe to allow us to use fifo API without local unsafe scope
#pragma unsafe arrays //Added because we have now added volume and are asking a lot performance-wise
unsafe void XUA_Buffer_lite(
  chanend ?c_aud_ctl,
  chanend c_aud_out,
  chanend ?c_feedback,
  chanend c_aud_in,
  chanend c_sof,
  in port ?p_for_mclk_count,
#if ( 0 < HID_CONTROLS )
  chanend c_hid,
#endif
  chanend c_audio_hub) {

  debug_printf("%d\n", MAX_OUT_SAMPLES_PER_SOF_PERIOD);

  //These buffers are unions so we can access them as different types
  int8_t buffer_aud_out_bytes[OUT_AUDIO_BUFFER_SIZE_BYTES];
  int8_t buffer_aud_in_bytes[IN_AUDIO_BUFFER_SIZE_BYTES];

  // unsigned in_subslot_size = (AUDIO_CLASS == 1) ? (get_device_to_usb_bit_res()/8) : HS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES;
  // unsigned out_subslot_size = (AUDIO_CLASS == 1) ? (get_usb_to_device_bit_res()/8) : HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES;

  unsigned in_subslot_size = (AUDIO_CLASS == 1) ? FS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES : HS_STREAM_FORMAT_INPUT_1_SUBSLOT_BYTES;
  unsigned out_subslot_size = (AUDIO_CLASS == 1) ? FS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES : HS_STREAM_FORMAT_OUTPUT_1_SUBSLOT_BYTES;

  debug_printf("in_subslot_size: %u\n", in_subslot_size);
  debug_printf("out_subslot_size %u\n", out_subslot_size);

  //Asynch feedback calculation
  unsigned sof_count = 0;
  unsigned mclk_port_counter_old = 0;
  long long feedback_value = 0;
  unsigned mod_from_last_time = 0;
  const unsigned mclk_hz = MCLK_48;
  unsigned int fb_clocks[1] = {0};


  //Endpoints
  XUD_ep ep_aud_out = XUD_InitEp(c_aud_out);
  XUD_ep ep_aud_in = XUD_InitEp(c_aud_in);
  XUD_ep ep_feedback = 0;
  if (!isnull(c_feedback)) { ep_feedback = XUD_InitEp(c_feedback); }

  unsigned num_samples_received_from_host = 0;
  unsigned num_samples_to_send_to_host = 0;

  unsigned input_interface_num = 0;
  unsigned output_interface_num = 0;

  //Enable all EPs
  XUD_SetReady_OutPtr(ep_aud_out, (unsigned)buffer_aud_out_bytes);
  XUD_SetReady_InPtr(ep_aud_in, (unsigned)buffer_aud_in_bytes, num_samples_to_send_to_host);
  if (!isnull(c_feedback)) {
    XUD_SetReady_InPtr(ep_feedback, (unsigned)fb_clocks, (AUDIO_CLASS == 2) ? 4 : 3);
  }

#if ( 0 < HID_CONTROLS )
  XUD_ep ep_hid = XUD_InitEp(c_hid);
  unsigned char hidData[HID_MAX_DATA_BYTES] = {0U};
  unsigned hid_ready_flag = 0U;
  unsigned hid_ready_id = 0U;

  while (!hidIsReportDescriptorPrepared());

  UserHIDInit();
  unsigned hidFirstReportId = hidIsReportIdInUse();
  unsigned hidReportIdLimit = hidGetReportIdLimit();
#endif

  int8_t samples_in[BYTES_PER_32B_WORD * NUM_USB_CHAN_IN] = {0};
  int8_t samples_out[BYTES_PER_32B_WORD * NUM_USB_CHAN_OUT] = {0};

  //FIFOs from EP buffers to audio
  int8_t host_to_device_fifo_storage[BYTES_PER_32B_WORD * OUT_FIFO_LENGTH]; //OUT_FIFO_LENGTH is in samples. Allocate memory enough to store highest bit-res(32 bit) samples
  int8_t device_to_host_fifo_storage[BYTES_PER_32B_WORD * IN_FIFO_LENGTH];  //IN_FIFO_LENGTH is in samples. Allocate memory enough to store highest bit-res(32 bit) samples


  mem_fifo_t host_to_device_fifo = {
    OUT_FIFO_LENGTH, //FIFO size in samples
    host_to_device_fifo_storage,
    0,
    0,
  };

  mem_fifo_t device_to_host_fifo = {
    IN_FIFO_LENGTH, //FIFO size in samples
    device_to_host_fifo_storage,
    0,
    0,
  };

  volatile mem_fifo_t * unsafe host_to_device_fifo_ptr = &host_to_device_fifo;
  volatile mem_fifo_t * unsafe device_to_host_fifo_ptr = &device_to_host_fifo;

  //XUD transaction variables passed in by reference
  XUD_Result_t result;
  unsigned length = 0;
  unsigned char c_tmp; //For select channel input by ref on EP0
  unsigned u_tmp; //For select channel input by ref on EP0
  unsigned s_tmp; //For select on channel from audiohub

  instrument_t dbg_struct;
  memset(&dbg_struct, 0, sizeof dbg_struct);

  struct XUA_host_status host_status;

  unsigned from_device_count = 0;
  unsigned to_device_count = 0;
  uint32_t samples_in_int32[NUM_USB_CHAN_IN];
  uint32_t samples_out_int32[NUM_USB_CHAN_OUT];
  // uint32_t d2hfreq_to_soffreq_ratio = get_device_to_usb_rate()  / SOF_FREQ_HZ;

  //Volumes are initialised to 0 (0dB) but multipliers are not initialised in XUD
  //so do it here..
  #define ZERO_DECIBEL_MULTIPLIER 0x20000000 //Q29 = 1.000000
  for(int i = 0; i < NUM_USB_CHAN_OUT; i++) {
    multOut[i] = ZERO_DECIBEL_MULTIPLIER;
  }
  for(int i = 0; i < NUM_USB_CHAN_IN; i++) {
    multIn[i] = ZERO_DECIBEL_MULTIPLIER;
  }

  timer tmr;
  

  while(1){
    select {
      // Handle control path from EP0
      // input_interface_num and output_interface_num are set using callbacks,
      // not here.
      // Note: All EP0 requests are ignored, dynamically switching sample rate/
      // resolution is unsupported in XUA Lite
      case !isnull(c_aud_ctl) => inct_byref(c_aud_ctl, c_tmp):
        unsigned cmd = c_tmp;
        debug_printf("c_aud_ctl cmd: %d\n", cmd);
        if (cmd == SET_SAMPLE_FREQ) {
          unsigned receivedSampleFreq = inuint(c_aud_ctl);
          debug_printf("SET_SAMPLE_FREQ: %d\n", receivedSampleFreq);
        } else if (cmd == SET_STREAM_FORMAT_IN) {
          unsigned formatChange_DataFormat = inuint(c_aud_ctl);
          unsigned formatChange_NumChans = inuint(c_aud_ctl);
          unsigned formatChange_SubSlot = inuint(c_aud_ctl);
          unsigned formatChange_SampRes = inuint(c_aud_ctl);
          debug_printf("SET_STREAM_FORMAT_IN: %d %d %d %d\n",
                       formatChange_DataFormat, formatChange_NumChans,
                       formatChange_SubSlot, formatChange_SampRes);
        } else if (cmd == SET_STREAM_FORMAT_OUT) {
          XUD_BusSpeed_t busSpeed;
          unsigned formatChange_DataFormat = inuint(c_aud_ctl);
          unsigned formatChange_NumChans = inuint(c_aud_ctl);
          unsigned formatChange_SubSlot = inuint(c_aud_ctl);
          unsigned formatChange_SampRes = inuint(c_aud_ctl);
          debug_printf("SET_STREAM_FORMAT_OUT: %d %d %d %d\n",
                       formatChange_DataFormat, formatChange_NumChans,
                       formatChange_SubSlot, formatChange_SampRes);
        } else {
          debug_printf("Unhandled command\n");
        }
        outct(c_aud_ctl, XS1_CT_END);
        debug_printf("end c_aud_ctl\n");
        break;

      // SOF handling
      case inuint_byref(c_sof, u_tmp):
        static int cc = 0; if(++cc == 8000){debug_printf("SoF\n");cc=0;}

        //timer dbg_tmr; int t0, t1; dbg_tmr :> t0;
        unsigned sof_time;
        tmr :> sof_time;
        dbg_struct.sof_diff = dbg_struct.sof_time - sof_time;
        dbg_struct.sof_time = sof_time;
        // GET Time Stamp of mclk (clock count)
        if (!isnull(c_feedback)) {
          unsigned mclk_port_counter = 0;
          asm volatile(" getts %0, res[%1]" : "=r" (mclk_port_counter) : "r" (p_for_mclk_count));
          do_feedback_calculation(sof_count, mclk_hz, mclk_port_counter,
                                  mclk_port_counter_old, feedback_value,
                                  mod_from_last_time, fb_clocks);
        }


        // if (host_status.seen_in && !host_status.streaming_in) {
        //     fifo_reset_fill(host_to_device_fifo_ptr, OUT_FIFO_TARGET, out_subslot_size);
        //     fifo_reset_fill(device_to_host_fifo_ptr, IN_FIFO_TARGET, in_subslot_size);
        //     debug_printf("sirst\n");
        // }
        // if (host_status.seen_out && !host_status.streaming_out) {
        //     fifo_reset_fill(host_to_device_fifo_ptr, OUT_FIFO_TARGET, out_subslot_size);
        //     fifo_reset_fill(device_to_host_fifo_ptr, IN_FIFO_TARGET, in_subslot_size);
        //     debug_printf("sorst\n");
        // }

        host_status.streaming_in = host_status.seen_in;
        host_status.streaming_out = host_status.seen_out;
        host_status.seen_in = 0;
        host_status.seen_out = 0;

        sof_count++;
        //dbg_tmr :> t1; debug_printf("s%d\n", t1 - t0);
        break;

      //Receive samples from host
      case XUD_GetData_Select(c_aud_out, ep_aud_out, length, result):
        static int ce = 0; if(++ce == 8000){debug_printf("h2d\n");ce=0;}
        //timer dbg_tmr; int t0, t1; dbg_tmr :> t0;

        int t_samples_received;
        tmr :> t_samples_received;
        dbg_struct.recv_samples_delay = t_samples_received - dbg_struct.sof_time;

        num_samples_received_from_host = length / out_subslot_size;

        host_status.seen_out = 1;

        fifo_ret_t ret = fifo_block_push_fast(host_to_device_fifo_ptr, buffer_aud_out_bytes, num_samples_received_from_host, out_subslot_size);
        if (ret != FIFO_SUCCESS) {
            dbg_struct.h2d_full = 1;
            debug_printf("h2d full\n");
        }
        num_samples_to_send_to_host = num_samples_received_from_host;

        //Mark EP as ready for next frame from host
        XUD_SetReady_OutPtr(ep_aud_out, (unsigned)buffer_aud_out_bytes);
        //dbg_tmr :> t1; debug_printf("o%d\n", t1 - t0);
        break;

      //Send asynch explicit feedback value, but only if enabled
      case !isnull(c_feedback) => XUD_SetData_Select(c_feedback, ep_feedback, result):
        //timer dbg_tmr; int t0, t1; dbg_tmr :> t0;

        XUD_SetReady_In(ep_feedback, (fb_clocks, unsigned char[]), (AUDIO_CLASS == 2) ? 4 : 3);
        debug_printf("0x%x\n", fb_clocks[0]);
        //dbg_tmr :> t1; debug_printf("f%d\n", t1 - t0);
        break;

      //Send samples to host
      case XUD_SetData_Select(c_aud_in, ep_aud_in, result):
        static int cf = 0; if(++cf == 8000){debug_printf("d2h\n");cf=0;}

        //timer dbg_tmr; int t0, t1; dbg_tmr :> t0;

        host_status.seen_in = 1;
        if (!host_status.streaming_out) {
          //If host is not streaming out, send a fixed number of samples to host
          // i.e. Act as an asynchonous endpoint
          // TODO: Implement a feed-forward endpoint
          // num_samples_to_send_to_host = d2hfreq_to_soffreq_ratio * NUM_USB_CHAN_IN;
        } else {
          //If host is streaming out, send the number of samples received * num_chan_in:num_chan_out ratio
          // num_samples_to_send_to_host = (num_samples_received_from_host * (NUM_USB_CHAN_IN / NUM_USB_CHAN_OUT) * get_device_to_usb_rate()) / get_usb_to_device_rate();
        }

        num_samples_to_send_to_host = 0;

        fifo_ret_t ret = fifo_block_pop_fast(device_to_host_fifo_ptr, buffer_aud_in_bytes, num_samples_to_send_to_host, in_subslot_size);
        if (ret != FIFO_SUCCESS) {
          memset(buffer_aud_in_bytes, 0, sizeof(buffer_aud_in_bytes));
          dbg_struct.d2h_empty = 1;
          debug_printf("d2h empty\n");
        }
        unsigned input_buffer_size = num_samples_to_send_to_host * in_subslot_size;
        XUD_SetReady_InPtr(ep_aud_in, (unsigned) buffer_aud_in_bytes, input_buffer_size);
        //dbg_tmr :> t1; debug_printf("i%d\n", t1 - t0);
        break;

      //Exchange samples with audiohub. Note we are using channel buffering here to act as a FIFO
      //this is happening at 48kHz
      //First grab outbound samples (processed mic) on way to host
      case inuint_byref(c_audio_hub, s_tmp):
        static int cd = 0; if(++cd == 48000){debug_printf("aud\n");cd=0;}
        fifo_block_pop_fast(host_to_device_fifo_ptr, (int8_t*)samples_out_int32, NUM_USB_CHAN_OUT, out_subslot_size);
        XUA_transfer_samples(c_audio_hub, (unsigned*)samples_out_int32, (unsigned*)samples_in_int32);

        //timer dbg_tmr; int t0, t1; dbg_tmr :> t0;
        // Receive samples from audiohub

#if 0
        int64_t result = (int64_t)s_tmp * multIn[0];
        // Take upper word but shift left by 3, this is because the multipliers are caclulated as Q29 in xua_ep0_uacreqs.xc
        samples_in_int32[0] = (uint32_t)(result >> (32 - 3));
        for (int i = 1; i < NUM_USB_CHAN_IN; i++){
            c_audio_hub :> s_tmp;
            int64_t result = (int64_t)s_tmp * multIn[i];
            // Take upper word but shift left by 3, this is because the multipliers are caclulated as Q29 in xua_ep0_uacreqs.xc
            samples_in_int32[i] = (uint32_t)(result >> (32 - 3));
        }


        // Pop samples from host to device fifo and unpack/left align to 32 bit
        fifo_ret_t ret;
        if(to_device_count == 0) //in case host_to_device rate is 16kHz, pop one out of every 3 times from the fifo
        {
            ret = fifo_block_pop_fast(host_to_device_fifo_ptr, samples_out, NUM_USB_CHAN_OUT, out_subslot_size);
            if (ret != FIFO_SUCCESS) {
                memset(samples_out, 0, sizeof(samples_out));
                if (host_status.streaming_out && output_interface_num != 0) {
                    dbg_struct.h2d_empty = 1;
                    debug_printf("h2d empty\n");
                }
            }

            unpack_buff_to_samples((uint8_t*)samples_out, NUM_USB_CHAN_OUT, out_subslot_size, samples_out_int32);
        }

        // Send samples to audiohub
        for (int i = 0; i < NUM_USB_CHAN_OUT; i++) {
            int64_t result = (int64_t)((int32_t)samples_out_int32[i]) * multOut[i];
            // Take upper word but shift left by 3, this is because the multipliers are caclulated as Q29 in xua_ep0_uacreqs.xc
            uint32_t sample = (uint32_t)(result >> (32 - 3));
            c_audio_hub <: sample;
        }

        // Pack samples to int8_t and push samples to device to host fifo
        if(from_device_count == 0) //in case device_to_host rate is 16kHz, push one out of every 3 times into the fifo
        {
            pack_samples_to_buff(samples_in_int32, NUM_USB_CHAN_IN, in_subslot_size, (uint8_t*)samples_in);

            ret = fifo_block_push_fast(device_to_host_fifo_ptr, samples_in, NUM_USB_CHAN_IN, in_subslot_size);
            if (ret != FIFO_SUCCESS) {
                if (host_status.streaming_in && input_interface_num != 0) {
                    dbg_struct.d2h_full = 1;
                    debug_printf("d2h full\n");
                }
            }
        }
        /* increment from_device_count
         * If device_to_usb rate is 48kHz, from_device_count will always be 0, and in every interaction with audiohub, we push 1 sample
         * into the device_to_host FIFO.
         * If device_to_usb rate is 16kHz, from_device_count will be 0,1,2,0,1,2.. which means, in every 3rd interaction with audiohub,
         * we push one sample into the device_to_host FIFO
         */
        from_device_count++;
        if(from_device_count >= f48khz_to_curDeviceToUsb_ratio) {
            from_device_count = 0;
        }

        /* increment to_device count
         * If usb_to_device rate is 48kHz, to_device_count will always be 0, and in every interaction with audiohub we pop 1 sample from
         * host_to_device FIFO and send to audiohub.
         * If usb_to_device rate is 16kHz, to_device_count will be 0,1,2..and whenever it is 0, we pop a sample from host to device FIFO
         * to send to audiohub and when it is 1 and 2, we send the same sample to audiohub. So every sample popped from host_to_device FIFO
         * is sent 3 times to audiohub.
         */
        to_device_count++;
        if(to_device_count >= f48khz_to_curUsbToDevice_ratio) {
            to_device_count = 0;
        }
#endif


        //dbg_tmr :> t1; debug_printf("a%d\n", t1 - t0);
        break;

#if ( 0 < HID_CONTROLS )
      /* HID Report Data
         Sends a HID Report periodically.
         The USB Host can suspend the periodic report by sending a SetIdle request.
         Sending the report releases the latch on processing the level of the trigger mechanism.
      */

      case XUD_SetData_Select(c_hid, ep_hid, result):
        hid_ready_flag = 0U;
        unsigned reportTime;
        tmr :> reportTime;
        hidCaptureReportTime(hid_ready_id, reportTime);
        hidCalcNextReportTime(hid_ready_id);
        debug_printf("XUA_Buffer_lite -- called CalcNextReportTime() for id %d\n", hid_ready_id);
        break;

#endif

//       default:
//         input_interface_num = g_input_interface_num;
//         output_interface_num = g_output_interface_num;

// #if ( 0 < HID_CONTROLS )
//         if (!hid_ready_flag)
//         {
//             for (unsigned id = hidFirstReportId; id < hidReportIdLimit; id++)
//             {
//                 if ( hidIsChangePending(id) || !HidIsSetIdleSilenced(id) )
//                 {
//                     int hidDataLength = (int) UserHIDGetData(id, hidData);
//                     debug_printf("XUA_Buffer_lite -- called UserHIDGetData() for id %d, returned length %d\n", id, hidDataLength);
//                     XUD_SetReady_In(ep_hid, hidData, hidDataLength);
//                     hidClearChangePending(hid_ready_id);
//                     debug_printf("XUA_Buffer_lite -- called hidClearChangePending() for id %d\n", hid_ready_id);
//                     hid_ready_id = id;
//                     hid_ready_flag = 1U;
//                     break;
//                 }
//             }
//         }
// #endif

//         break;
    }
  }
}

#endif
