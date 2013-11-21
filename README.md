
# virc - Silly IRC client for vim
virc is an experiment with an IRC client written as a Vim plugin.

## How to use
Preferably, not at all.  This is mostly a silly expermient.

Requires vim to be compiled with support for Lua scripting (`:version` must
show `+lua`).

Settings (nickname, realname etc) are hard-coded for now.

    $ cd /path/to/virc/src
    $ vim +'set rtp+=.' +'luafile main.lua'


## Screenshot
![virc screenshot](https://github.com/FireyFly/virc/raw/master/res/screenshot.png)

