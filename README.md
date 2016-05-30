AWB
===

Arcan Workbench, Desktop- like script for Arcan

*Note that this project is no longer maintained. It worked up until Arcan 0.4,
but the drastic changes to how the database for launch targets are managed,
and some minor adjustments to rendertargets, this will flat out fail to work
or die on script errors randomly.*

This is primarily a sandbox for testing out new ideas and for finding
rough spots in the Lua API and not intended as desktop environment or
as a shining example on how to code such a thing in Arcan. Some of the
lessons learned are fed back into API changes, and others into support
scripts.

Look at the helper- images in the Wiki on the github site for a rough
idea of existing features.

Use
===
This assumes a pre-existing arcan installation, preferably some targets
and configurations in the database (see arcan-legacy for converting old
ones).

It also exposes a CONNPATH as "awb" for external processes to connect
through.

Default keybindings:
LCTRL - toggle mouse grab on / off
ESCAPE - cancel
F11 - Window gather / Scatter
F12 - Focus-lock current window

Debug keybindings (-g -g):
F3 - store snapshot to syssnap.lua
F5 - dump context usage
F10 - dump mapped mouse handlers
F7 - dump meta information about item under cursor to stdout
F8 - toggle fullscreen recording to dump.mkv on/off

