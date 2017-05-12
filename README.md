AWB
===

Arcan Workbench, Desktop- like script for Arcan (~2012-2013)

*Note that this project is no longer maintained. The current version works
with the arcan 0.5+ setup, while older (0.4, ...) should use the awb-04 tag.*

The last set of patches was just to bring it up to "mostly-working" form for
the Amiga-500 30-year anniversary.

This was used as a sandbox for testing out ideas and finding rough spots in the
Lua API - not intended as a stable work environment or an example on how to
build something like that, and the code is awful. Some of the lessons learned
was fed back into other support scripts and into the engine itself.

Use
===
This assumes a pre-existing arcan installation, preferably some targets
and configurations in the database (see arcan-legacy for converting old
ones).

It also exposes an ARCAN\_CONNPATH as "awb" for external processes to
connect through.

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

