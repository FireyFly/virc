" Vim syntax file
" Language:     X-Chat Log Files
" Maintainer:   Jonas Höglund <vim@firefly.nu>
" Filenames:    xchatlogs/*.log
" Last Change:  2012-06-22

if exists("b:current_syntax")
  finish
endif


"""" Syntactic entries """"""""""""""""""""""""""""""""""""""""""""""
syn match    vircChannelTimestamp   "^\[[:0-9]\+\]"
\            nextgroup=vircChannelMessage,vircChannelSysNote
"syn region   vircChannelStamped     matchgroup=vircChannelTimestamp
"\                                   start="\[[:0-9]\+\]"  end="$"
"\            keepend  contains=@vircChannelLine

"syn region   vircChannelNick        matchgroup=Delimiter start="<" end=">"
"\                                   contained

syn match    vircChannelNick        "\s*[^<>│ \t]\+" contained
syn match    vircChannelChannel     "#\S\+"

syn match    vircChannelSep         "\>│\<"     contained

syn match    vircChannelMessage     " <\S\+> "  contained
\            contains=vircChannelNick nextgroup=vircChannelMessageBody
syn match    vircChannelMessage     " \+\S\+│"   contained
\            contains=vircChannelNick,vircChannelSep nextgroup=vircChannelMessageBody
syn match    vircChannelMessageBody ".*"        contained contains=@vircFormatting

syn match    vircChannelSysNote     " \* "      contained nextgroup=vircChannelNick
"syn match    vircChannelSysNoteTail ".\+"       contained

syn cluster  vircChannelLine        contains=vircChannelMessage,vircChannelSysNote


"" Formatting
for i in range(1, 9)
  " Add fg
  exec "syn match vircFormatting_fg" . i . " '\\(0" . i . "\\|" . i
\    . "\\D\\@=\\)[^]*'"
\    . " contains=vircControlChar nextgroup=vircControlChar"

  " Add bg
  exec "syn match vircFormatting_bg" . i . " '\\d\\d\\?,\\(0" . i
\    . "\\|" . i . "\\D\\@=\\)[^]*'"
\    . " contains=@vircFormatting_2,vircControlChar nextgroup=vircControlChar"

  " Register in the formatting cluster
  exec "syn cluster  vircFormatting_2 add=vircFormatting_fg" . i
  exec "syn cluster  vircFormatting add=vircFormatting_fg" . i
\                                   . ",vircFormatting_bg" . i
endfor
for i in range(10, 16)
  "syn match vircFormatting_fg10 "10[^]*"
  exec "syn match vircFormatting_fg" . i . " '" . i "[^]*'"
  exec "syn cluster  vircFormatting2 add=vircFormatting_fg" . i

  exec "syn match vircFormatting_bg" . i . " '\\d\\d\\?," . i "[^]*'"
  exec "syn cluster  vircFormatting add=vircFormatting_bg" . i
endfor

syn match vircControlChar "\d\{0,2}\(,\d\{0,2}\)\?\|"  contained conceal
"syn cluster vircFormatting add=vircControlChar

"syn cluster  vircFormatting
"\ contains=vircFormatting_fg1,vircFormatting_fg2,vircFormatting_fg3
"\ add=vircFormatting_fg4,vircFormatting_fg5


"""" Highlighting """""""""""""""""""""""""""""""""""""""""""""""""""
hi def link  vircChannelMessage        Normal
hi def link  vircChannelSysNote        Comment
hi def link  vircChannelSep            Comment
hi def link  vircChannelNick           Type
hi def link  vircChannelTimestamp      Identifier
hi def link  vircChannelChannel        Special

hi vircFormatting_fg1  ctermfg=0
hi vircFormatting_fg2  ctermfg=4
hi vircFormatting_fg3  ctermfg=2
hi vircFormatting_fg4  ctermfg=9
hi vircFormatting_fg5  ctermfg=1
hi vircFormatting_fg6  ctermfg=5

hi vircFormatting_fg14 ctermfg=8
hi vircFormatting_fg16 ctermfg=7


hi vircFormatting_bg1  ctermbg=0
hi vircFormatting_bg2  ctermbg=4
hi vircFormatting_bg3  ctermbg=2
hi vircFormatting_bg4  ctermbg=9
hi vircFormatting_bg5  ctermbg=1
hi vircFormatting_bg6  ctermbg=5

hi vircFormatting_bg14 ctermbg=8
hi vircFormatting_bg16 ctermbg=7
"for i in range(1,16)
"  exec "hi vircFormatting_fg" . i . " ctermfg=" . i
"endfor


let b:current_syntax = "virc-channel"

