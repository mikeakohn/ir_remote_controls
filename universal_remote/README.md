
Universal Remote
================

This is an update to the IR remote control projects.  This time
the remote is configurable over UART so that they don't require
different firmware to talk to different TV's and devices.

Commands
--------

* p: Print current settings (in the JSON format below)
* n[hex]: Set the length of HEADER_ON
* f[hex]: Set the length of HEADER_OFF
* o[hex]: Set the length of a ONE (and space)
* z[hex]: Set the length of a ZERO
* b[hex]: Set the number of bits for a command

Settings JSON
-------------

When sending a 'p', the output will look like this:

    {
      'header_on': 0x02a8,
      'header_off': 0x0154,
      'one': 0x0154,
      'zero': 0x0a09,
      'gap_length': 0x1d7b,
      'divider': 0x002a,
      'bits': 0x0020,
      'baud_div': 0x01bb,
      'timer_div': 0x0037,
    }

Note baud_div * 9600 should equal CPU frequency (close to 4MHz)


