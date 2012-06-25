" Vim syntax file
" Language:     X-Chat Log Files
" Maintainer:   Jonas Höglund <vim@firefly.nu>
" Filenames:    xchatlogs/*.log
" Last Change:  2012-06-22

if exists("b:current_syntax")
  finish
endif


"""" Syntactic entries """"""""""""""""""""""""""""""""""""""""""""""
" Log messages are special messages indicating beginnig/end of logging
"syn match    irclogLogMessage      "^\*\*\*\*.*"

" Stamped messages are all messages that begins with timestamp
"syn region   irclogStampedLine      matchgroup=irclogTimestamp
"\                                   start="^\w\{3} \d\{2} [:0-9]\+"  end="$"
"\            keepend  contains=irclogSysMessage,irclogTextMessage

" Sys messages are stamped messages with meta-information (joins, quits, ...)
"syn match    irclogSysMessage       " \*\t.*"  contained
"\                                   contains=@irclogSysMessages

"syn region   irclogJoinQuitMessage  matchgroup=irclogNick  start="\t\S\+"
"\                                   matchgroup=NONE        end="has \w\+"
"\                                   contained  oneline  transparent

"syn cluster  irclogSysMessages      contains=irclogJoinQuitMessage

" Regular message lines
"syn match    irclogTextMessage      " <\S\+>.*" contained
"\                                   contains=irclogNick
"syn region   irclogNick             matchgroup=Delimiter start="<" end=">"
"\                                   contained

syn region   vircChannelStampedLine matchgroup=vircChannelTimestamp
\                                   start="\[[:0-9]\+\]"  end="$"
\            keepend  contains=@vircChannelLine

syn region   vircChannelNick        matchgroup=Delimiter start="<" end=">"
\                                   contained

syn match    vircChannelBareNick    "\S\+" contained nextgroup=vircChannelSysNoteTail

syn match    vircChannelChannel     "#\S\+"

syn match    vircChannelMessage     " <\S\+>.*" contained contains=vircChannelNick
syn match    vircChannelSysNote     " \* "      contained nextgroup=vircChannelBareNick
syn match    vircChannelSysNoteTail ".\+"       contained

syn cluster  vircChannelLine        contains=vircChannelMessage,vircChannelSysNote



"""" Highlighting """""""""""""""""""""""""""""""""""""""""""""""""""
hi def link  vircChannelMessage        Normal
hi def link  vircChannelSysNote        Comment
hi def link  vircChannelSysNoteTail    vircChannelSysNote
hi def link  vircChannelNick           Type
hi def link  vircChannelBareNick       vircChannelNick
hi def link  vircChannelTimestamp      Identifier
hi def link  vircChannelChannel        Special


let b:current_syntax = "virc-channel"

