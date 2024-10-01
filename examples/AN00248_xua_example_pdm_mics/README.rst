
Using lib_xua with lib_mic_array
================================

Summary
-------

This applicaition note describes how to use ``lib_mic_array`` in conjunction with ``lib_xua``
to implement a USB Audio device with the ability to record from multiple PDM microphones.

Software dependencies
.....................

For a list of direct dependencies, look for APP_DEPENDENT_MODULES in the ``CMakeLists.txt`` Makefile.

Required hardware
.................

The example code provided with the application has been implemented
and tested on the XK-EVK-XU316 board.

Prerequisites
.............

 * This document assumes familiarity with the XMOS xCORE architecture,
   the XMOS tool chain and the xC language. Documentation related to these
   aspects which are not specific to this application note are linked to in
   the references appendix.



