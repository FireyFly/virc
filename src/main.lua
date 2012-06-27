-- FIXME: Temporary, to make development easier!
package.loaded['./connection'] = nil
package.loaded['./ircsock']    = nil
package.loaded['./vim-tree']   = nil
package.loaded['./util']       = nil
package.loaded['./commands']   = nil

local connection = require './connection'
local tree       = require './vim-tree'
local util       = require './util'


-- Configuration
local config = { nick      = "FF|Test"
               , ident     = "virc"
               , real_name = "Testing testing"

               -- the server to connect to
               , hostname  = "chat.freenode.net"
               , port      = 6667
               }


-- the connection
conn = connection.open(config)

---- Vim interfacing ------------------------------------------------
-- This part sets up the interface and associates various Vim events
-- with Lua actions.  This is the only part with interleaved vimscripts
-- (except 'vim-tree').

-- allows for simple use of multiline strings for performing multiple commands
local function vim_do(str) vim.command(str) end

-- Timers for keeping IRC connections alive -- calls irc_tick() periodically
vim_do [=[
  function! Timer()
    lua irc_tick()
    call feedkeys("f\e")
  endf
]=]
vim_do [=[
  function! TimerI()
    lua irc_tick()
    call feedkeys("a\<BS>")
  endf
]=]

local function setupView()
  -- shared setup stuff that all IRC-related buffers must have (such as calling
  -- the IRC connection timers periodically).
  local function setup_shared()
    vim.command("setlocal updatetime=800")
    vim.command("autocmd CursorHold  <buffer> call Timer()")
    vim.command("autocmd CursorHoldI <buffer> call TimerI()")
  end

  ---- prepare windows ----
  -- the main (channel) window
--vim.command("botright vnew")
  vim.command("enew")
  local chan_win = vim.window()

  -- the channel tree window
  vim_do [=[
    20vnew
    setlocal bt=nofile nobl nonu ft=virc-tree
    setlocal stl=%<Channels\ %=[%3(%L%)]
    nnoremap <buffer> <C-j> Go
    inoremap <buffer> <CR> <Esc>:lua irc_channel_accept()<CR>dd
  ]=]
  setup_shared()
  vim.command "au BufUnload <buffer> lua irc_close()"
  local chantree = tree.Tree.wrap(vim.window())

  chan_win()
  -- the input window
  vim_do [=[
    belowright silent 1new
    setlocal bt=nofile nobl nonu ft=virc-input
    inoremap <buffer> <CR> <Esc>:lua irc_input_accept()<CR>ddi
    setlocal stl=%<Input\ %=[%n]\ 
  ]=]
  vim.command "au BufUnload <buffer> lua irc_close()"
  setup_shared()
  local input_win = vim.window()

  -- Creates a new buffer in the channel window and makes it the current buffer
  -- of that window.  Resets focus to whichever window the user had focused.
  local function createBuffer(label)
    -- remember the current window
    local curr_win = vim.window()

    -- switch to the chan window and init new buffer
    chan_win()
    vim_do(([=[
      enew
      setlocal bt=nofile bh=hide nonu ft=virc-channel
      setlocal stl=%%<%s\ %%=[%%n]\ 
      setlocal cole=2 cocu=nvic nolist lbr wrap
    ]=]):format(label:gsub(" ", "\\ ")))
    setup_shared()

    -- extract the buffer, reset window & return buffer
    local buf = chan_win.buffer
    curr_win()

    return buf
  end

  -- Closes all IRC-related buffers and unassociates autocommands from those
  -- buffers..
  local function close_ui(self)
    -- remove associated buffers completely
    local function delete_buf(buf)
      if buf:isvalid() then
        local s = tostring(buf.number)
        vim.command("autocmd! *  <buffer=" .. s ..">")
        vim.command("bdelete " .. s)
        return true
      end
    end

    delete_buf(self.tree.buf)
    delete_buf(self.input.buf)

    for _,entry in self.tree:entries() do
      delete_buf(entry.buf)
    end
  end

  local function window_to_view(win, extras)
    local res = extras or {}
    res.win = win
    res.buf = win.buffer
    return res
  end
  return { channel = window_to_view(chan_win)
         , input   = window_to_view(input_win)
         , tree    = chantree

         , createBuffer = createBuffer
         , close_ui     = close_ui
         }
end

-- initialise the view
view = setupView()
local tree  = view.tree
local input = view.input.win


local function tree_entry_callback(self)
  local currWin = vim.window()

  view.active = self
  tree:update({name=self.name, status=" "})

  view.channel.win()
  self.buf()
  currWin()
end

--[[
function irc_entered_buffer()
  tree:update({name=view.active.name, state="x"})
end
--]]

local function create_tree_entry(name, line, kind, padding)
  local buf = view.createBuffer(line)
--vim.command(("au BufHidden <buffer=%d> lua irc_entered_buffer()"):format(buf.number))

  local entry = { name     = name
                , label    = line
                , buf      = buf

                , type     = kind
                , padding  = padding

                , status    = " "
                , status_no = 0

                , callback = tree_entry_callback
                }

  view.active = entry
  tree:append(entry)
end

create_tree_entry("server", "Server", 'server')


-- Prints the given arguments to the specified buffer (channel name).  If the
-- given name is '*active', then the currently active buffer will be used.  An
-- optional `level` (second parameter, if it's a number) represents the
-- importance of this message (default 0. 10 is a PRIVMSG).
--   If the first actual string to print contains any '%' signs, it's taken as a
-- printf-style string and passed to string.format.  Otherwise, the parameters
-- are stringified and joined together with a space.
function print_to(name, level, str, ...)
  -- `level` should default to 0
  if type(level) ~= 'number' then
    table.insert(arg, 1, str)
    str = level
    level = 0
  end

  -- must supply an actual target buffer name
  if name == nil then error("print_to: name is `nil`!", 2) end

  -- fetch the specified buffer
  local buf
  if name == "*active" then
    buf = view.channel.win.buffer

  else
    local entry = assert(tree:get({name=name}))
    buf = entry.buf
  end

  local status_map = { " ", "·", "-", "*", "#", "!" }

  -- mark tab as modified, if appropriate
  local win     = view.channel.win
  local currWin = vim.window()
  if not (buf == win.buffer and win == currWin)
      and (buf.status_no or 0) < level then
    tree:update({ name      = name
                , status_no = level
                , status    = status_map[level] or "*"
                })
  end

  -- Check for percentages, and if so, use string.format
  local plain
  if str:find("%", 1, true) then
    plain = string.format(str, unpack(arg))

  else
    -- fall back to just concatenating all the arguments
    table.insert(arg, 1, str)

    -- ...but we need to make sure that they're strings first!
    local mapped = {}
    for _,v in ipairs(arg) do
      table.insert(mapped, tostring(v))
    end

    plain = table.concat(mapped, " ")
  end

  -- prepare timestamp
  local stamp = os.date("[%H:%M:%S] ")

  -- actually append to the buffer
  buf:insert(stamp .. plain)

  -- scroll down the main window if appropriate
  local win = view.channel.win
  local currWin = vim.window()
  if win:isvalid() and buf:isvalid() and win == currWin
      and win.buffer == buf and win.line == #buf - 1 then
    win.line = #buf
  end
end


local c = { warn  = function(...) print_to('*active', unpack(arg)) end
          , error = function(...) print_to('*active', "Error:", unpack(arg)) end
          }


---- Event listeners ------------------------------------------------
-- These listen to various kinds of messages from the IRC connection
-- and presents them to the user by updating the UI.
conn:on("server-msg", function(msg)
  print_to("server", "%s", msg)
end)

conn:on("unimplemented", function(msg)
  print_to("server", "-- [no handler]: %s", tostring(msg))
end)

conn:on("self-join", function(chan)
  -- create a tree map entry if none exists
  if tree:get({name=chan}) == nil then
    create_tree_entry(chan, chan, 'channel', "  ")
  end
end)

conn:on("join", function(user, chan)
  print_to(chan, "* %s has joined %s", tostring(user), chan)
end)

conn:on("part", function(user, chan)
  print_to(chan, "* %s has left %s", tostring(user), chan)
end)

conn:on("nick", function(oldnick, newnick)
  for chan in pairs(conn.users[newnick].channels) do
    print_to(chan, "* %s is now known as %s", oldnick, newnick)
  end
end)

conn:on("quit", function(user, message)
  for chan in pairs(conn.users[user.nick].channels) do
    print_to(chan, "* %s has quit IRC (%s)", user.nick, message)
  end
end)

conn:on("message", function(target, source, msg)
  print_to(target, "<%s> %s", tostring(source), msg)
end)

conn:on("notice", function(variant, target, source, msg)
  local target_s = (variant == "channel") and " [to " .. target .. "]" or ""

  print_to("*active", "-%s%s- %s", tostring(source), target_s, msg)
end)

local chan_type_map = { ["@"]="secret", ["*"]="private" }
conn:on("names", function(chan, kind, users)
  local chanType = chan_type_map[kind]
  if chanType then
    print_to(chan, "* Channel %s is %s.", chan, chanType)
  end

  local lines = {}
  local names = {}

  local ctr = 0
  for nick,kind in pairs(users) do
    table.insert(names, ("[%10.10s]"):format(kind .. nick))
    ctr = ctr + 1

    if math.fmod(ctr, 8) == 0 then
      table.insert(lines, table.concat(names, ""))
      names = {}
    end
  end

  table.insert(lines, table.concat(names, ""))

  for _,line in ipairs(lines) do
    print_to(chan, "* Names: %s", line)
  end
end)

conn:on("names-end", function(chan, msg)
  print_to(chan, "* Names:", msg)
end)

conn:on("ctcp", function(target, source, cmd, args)
  local s = cmd
  if #args > 0 then s = s .. " " .. args end

  -- first, check for CTCP action--we don't want the user to see this as a form
  -- of CTCP, really.
  if cmd == "ACTION" then
    print_to(target, "* %s %s", tostring(source), args)
    return
  end

  -- notify the user about the CTCP message
  c.warn("* CTCP [from %s] %s", tostring(source), s)

  -- act according to the CTCP command
  if cmd == "VERSION" then
    conn:ctcp_reply(target, "VERSION", "virc 0")

  elseif cmd == "PING" then
    conn:ctcp_reply(target, "PING", args)

  else
    c.warn("* Unknown CTCP request!")
  end
end)

conn:on("ctcp-reply", function(target, source, cmd, args)
  if cmd == "PING" then
    local val = tonumber(args)
    local delta = os.difftime(os.time(), val)

    c.warn(("* Ping reply from %s: %d seconds."):format(tostring(source), delta))

  else
    c.warn(("* CTCP-reply [from %s] %s %s"):format(tostring(source), cmd, args))
  end
end)

conn:on("topic", function(chan, topic)
  -- print text to channel
  if topic.initial then
    if topic.content then
      local datestamp = os.date("%c", topic.date)
      print_to(chan, "* Topic for %s is: %s", chan, topic.content)
      print_to(chan, "* Topic set by %s (%s)", topic.user, datestamp)

    else
      print_to(chan, "* No topic set for %s.", chan)
    end

  else
    print_to(chan, "* %s changed topic to: %s", tostring(topic.user), topic.content)
  end

  -- TODO: update the statusline of the corresponding buffer
end)

conn:on("connected", function()
  c.warn("* Connected successfully!")
  conn:join("#test")
end)

conn:on("debug", function(...)
  if tree:get({name="debug"}) == nil then
    create_tree_entry("debug", "Debug", 'debug')
  end

  print_to("debug", unpack(arg))
end)


---- Slash commands -------------------------------------------------
commands = {} -- global, so that other modules can write directly to it.

commands["reload"] = function(conn, module_name)
  local module = package.loaded[module_name]

  if module == nil then
    error(("no module '%s' loaded"):format(tostring(module_name)))
  end

  package.loaded[module_name] = nil
  local new_module = require(module_name)

  -- clear the old module object, then copy props over from the new one
--for k   in pairs(module)     do module[k] = nil end
--for k,v in pairs(new_module) do module[k] = v   end

  print_to('*active', "- Reloaded module '%s' successfully", module_name)
end

require './commands'


---- Global functions -----------------------------------------------
-- These are called from the Vim side of things, on certain events.

-- Called from the Vim timer each time we should check the
-- connections for any new messages.
function irc_tick()
  conn:check()
end

-- Quits and closes all IRC-related buffers.  Called when chantree
-- or input field is closed.
function irc_close(msg)
  conn:quit(msg)
  irc_tick = function() end

  view:close_ui()
end

-- Called when <CR> is received from the *channel tree* buffer.
function irc_channel_accept()
  local line    = tree.buf[tree.win.line]
  local channel = util.trim(line)

  conn:join(channel)
end

-- Called when <CR> is received from the input buffer.
function irc_input_accept()
  local line = input.buffer[input.line]

  local firstChar = line:sub(1, 1)
  if firstChar == "/" then
    -- handle slash command
    local idx  = line:find(" ", 2, true) or #line + 1
    local cmd  = line:sub(2, idx - 1)
    local args = util.split(line:sub(idx + 1), " ")

    local fun = commands[cmd]

    if fun == nil then
      c.error("No such command: " .. cmd)
      return
    end

    -- call the command!
    local success, err = pcall(fun, conn, unpack(args))
    if not success then
      c.error(("(%s): %s"):format(cmd, err))
    end

  else
    -- no command; regular message
    if view.active.type == 'channel' or view.active.type == 'query' then
      local target = view.active.name
      conn:message(target, line)
      print_to(target, "<%s> %s", conn.state.user.nick, line)

    elseif view.active.type == 'server' then
      conn:sendraw(line)

      print_to('*active', ">> %s", line)

    else
      c.error(("unknown message recipient type: %s"):format(
                  tostring(view.active.type)))
    end
  end
end
