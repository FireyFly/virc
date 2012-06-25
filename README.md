
# virc - Silly IRC client for vim

## How to use
Preferably, not at all.  This is mostly a silly expermient.

Requires vim to be compiled with support for Lua scripting (`:version` must
show `+lua`).

Settings (nickname, realname etc) are hard-coded for now.

    $ vim +'set rtp+=.' +'luafile main.lua'

