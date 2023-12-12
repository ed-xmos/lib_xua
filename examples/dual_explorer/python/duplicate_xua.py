import re
import glob
from pathlib import Path
import shutil

xua_copy_suffix = "_2"

def replace_strings_in_file(file_path, replacements, output_file_path):

    try:
        with open(file_path, 'r') as file:
            file_content = file.read()

            # Perform replacements
            for old_string, new_string in replacements.items():
                # Use regular expression with word boundaries to match whole words only
                pattern = r'\b' + re.escape(old_string) + r'\b'
                file_content = re.sub(pattern, new_string, file_content)

        # Write modified content to a new file
        with open(output_file_path, 'w') as output_file:
            output_file.write(file_content)
            print(f"Replacements completed. Modified content saved to '{output_file_path}'.")

    except FileNotFoundError:
        print("File not found. Please provide a valid file path.")
    except Exception as e:
        print(f"An error occurred: {str(e)}")

this_file_path = Path(__file__).resolve().parent
input_path_root = this_file_path / "../../../lib_xua"
input_path_extensions = [".xc", ".c", ".h"]
output_dir = this_file_path / "../src/xua2"
Path(output_dir).mkdir(parents=True, exist_ok=True)

white_list = [
    "decouple.xc",
    "ep_buffer.xc",
    "decouple_interrupt.c",
    "xua_endpoint0.c",
    "xua_buffer.h",
    "xua_ep0_descriptors.h",
    "xua_buffer.h"
    ]

substitutions = [
  "__handle_audio_request_kernel_stack_end",
  "__handle_audio_request_handler",
  "XUA_Endpoint0_setVendorId",
  "concatenateAndCopyStrings",
  "XUA_Endpoint0_setStrTable",
  "XUA_Endpoint0_setVendorStr",
  "XUA_Endpoint0_setProductStr",
  "XUA_Endpoint0_setSerialStr",
  "XUA_Endpoint0_getVendorStr",
  "XUA_Endpoint0_getProductStr",
  "XUA_Endpoint0_getSerialStr",
  "XUA_Endpoint0_setProductId",
  "XUA_Endpoint0_getVendorId",
  "XUA_Endpoint0_getProductId",
  "XUA_Endpoint0_getBcdDevice",
  "XUA_Endpoint0_setBcdDevice",
  "XUA_Endpoint0_init",
  "XUA_Endpoint0_loop",
  "XUA_Endpoint0",
  "g_strTable",
  "devDesc_Audio2",
  "devDesc_Null",
  "devQualDesc_Audio2",
  "devQualDesc_Null",
  "cfgDesc_Audio2",
  "cfgDesc_Null",
  "DFU_mode_active",
  "g_curStreamAlt_Out",
  "g_curStreamAlt_In",
  "g_curUsbSpeed",
  "g_vendor_str",
  "g_product_str",
  "g_serial_str",
  "g_subSlot_Out_HS",
  "g_subSlot_Out_FS",
  "g_subSlot_In_HS",
  "g_subSlot_In_FS",
  "g_sampRes_Out_HS",
  "g_sampRes_Out_FS",
  "g_sampRes_In_HS",
  "g_sampRes_In_FS",
  "g_dataFormat_Out",
  "g_dataFormat_In",
  "g_chanCount_In_HS",
  "ep0_out",
  "ep0_in",
  "volsOut",
  "mutesOut",
  "volsIn",
  "mutesIn",
  "__handle_audio_request_kernel_stack_end",
  "__handle_audio_request_handler",
  "GetADCCounts",
  "XUA_Endpoint0_setVendorId",
  "concatenateAndCopyStrings",
  "XUA_Endpoint0_setStrTable",
  "XUA_Endpoint0_setVendorStr",
  "XUA_Endpoint0_setProductStr",
  "XUA_Endpoint0_setSerialStr",
  "XUA_Endpoint0_getVendorStr",
  "XUA_Endpoint0_getProductStr",
  "XUA_Endpoint0_getSerialStr",
  "XUA_Endpoint0_setProductId",
  "XUA_Endpoint0_getVendorId",
  "XUA_Endpoint0_getProductId",
  "XUA_Endpoint0_getBcdDevice",
  "XUA_Endpoint0_setBcdDevice",
  "XUA_Endpoint0_init",
  "XUA_Endpoint0_loop",
  "XUA_Endpoint0",
  "g_strTable",
  "devDesc_Audio2",
  "devDesc_Null",
  "devQualDesc_Audio2",
  "devQualDesc_Null",
  "cfgDesc_Audio2",
  "cfgDesc_Null",
  "DFU_mode_active",
  "g_curStreamAlt_Out",
  "g_curStreamAlt_In",
  "g_curUsbSpeed",
  "g_vendor_str",
  "g_product_str",
  "g_serial_str",
  "g_subSlot_Out_HS",
  "g_subSlot_Out_FS",
  "g_subSlot_In_HS",
  "g_subSlot_In_FS",
  "g_sampRes_Out_HS",
  "g_sampRes_Out_FS",
  "g_sampRes_In_HS",
  "g_sampRes_In_FS",
  "g_dataFormat_Out",
  "g_dataFormat_In",
  "g_chanCount_In_HS",
  "ep0_out",
  "ep0_in",
  "volsOut",
  "mutesOut",
  "volsIn",
  "mutesIn",
  "EnableBufferedPort",
  "ConfigAudioPortsWrapper",
  "XUA_Buffer_Ep",
  "fb_clocks",
  "feedbackValid",
  "g_speed",
  "XUA_Buffer",
  "g_freqChange",
  "masterClockFreq_ptr",
  "InitPorts_master",
  "samplesOut",
  "XUA_AudioHub",
  "dsdMode",
  "samplesIn",
  "testct_byref",
  "XUA_Buffer_Decouple",
  "buffer_aud_ctl_chan",
  "aud_to_host_usb_ep",
  "aud_from_host_usb_ep",
  "inZeroBuff",
  "audioBuffIn",
  "outAudioBuff",
  "g_numUsbChan_In",
  "handle_audio_request",
  "aud_to_host_fifo_end",
  "aud_to_host_fifo_start",
  "g_aud_from_host_wrptr",
  "aud_from_host_fifo_end",
  "aud_from_host_fifo_start",
  "g_maxPacketSize",
  "g_curSubSlot_In",
  "g_curSubSlot_Out",
  "g_numUsbChan_Out",
  "unpackState",
  "inUnderflow",
  "outOverflow",
  "outUnderflow",
  "g_aud_from_host_rdptr",
  "speedRem",
  "packData",
  "packState",
  "unpackData",
  "aud_data_remaining_to_device",
  "totalSampsToWrite",
  "sampsToWrite",
  "multOut",
  "multOutPtr",
  "multIn",
  "multInPtr",
  "g_aud_from_host_buffer",
  "g_aud_to_host_flag",
  "g_aud_from_host_flag",
  "g_aud_from_host_info",
  "g_freqChange_flag",
  "g_freqChange_sampFreq",
  "g_formatChange_SubSlot",
  "g_formatChange_DataFormat",
  "g_formatChange_NumChans",
  "g_formatChange_SampRes",
  "g_aud_to_host_wrptr",
  "g_aud_to_host_dptr",
  "g_aud_to_host_rdptr",
  "g_aud_to_host_fill_level",
  "aud_req_in_count",
  "aud_req_out_count",
  "XUA_Buffer_Ep",
  "fb_clocks",
  "feedbackValid",
  "g_speed",
  "XUA_Buffer",
  "g_freqChange",
  "masterClockFreq_ptr",
  "testct_byrefnot",
  "clockGen",
  "g_digData",
  "PllRefPinTask",
  "db_to_mult",
  "_Sdb_to_mult_0",
  "AudioClassRequests_2",
  "g_curSamFreq",
  "FeedbackStabilityDelay",
  "UpdateMixerOutputRouting",
  "UpdateMixMap",
  "UpdateMixerWeight",
  "ConfigAudioPorts",
  "device_reboot",
  "array_to_xc_ptr",
  "midi_in_parse",
  "reset_midi_state",
  "dump_midi_in_parse_state",
  "midi_out_parse",
  "queue_space",
  "queue_items",
  "queue_pop_byte",
  "queue_is_empty",
  "queue_push_byte",
  "queue_is_full",
  "queue_pop_word",
  "queue_push_word",
  "queue_init",
  "is_power_of_2",
  "usb_midi",
  "authenticating",
  "uin_count",
  "uout_count",
  "th_count",
  "mr_count",
  "icount",
  "midi_get_ack_or_data",
  "midi_send_ack",
]


# Find all source files according to input_path_extensions
source_files = []
for extension in input_path_extensions:
    source_list = glob.glob(str(input_path_root.resolve()) + f"/**/*{extension}", recursive=True)
    source_list = [path for path in source_list if not "/host/" in path] # remove /host dir
    source_files.extend(source_list)
    if extension == ".h":
        h_files = source_list

# Empty text replacement dict
replacements = {}

# Add all substitutions to replacements
for substitution in substitutions:
    replacements[substitution] = substitution + xua_copy_suffix

# Add all include file names to replacements
for source_file in source_files:
    if ".h" in Path(source_file).name:
        h_file = Path(source_file).name
        new_h_file = h_file.split(".")[0] + xua_copy_suffix + ".h"
        replacements[h_file] = new_h_file



for source_file in source_files:
    target_file = output_dir / (Path(source_file).stem + xua_copy_suffix + Path(source_file).suffix)
    print(Path(source_file).name)
    if True:
    # if Path(source_file).name in white_list:
        print(f"Copying and modifying: {source_file}")
        # shutil.copy2(source_file, target_file)
        replace_strings_in_file(source_file, replacements, target_file)