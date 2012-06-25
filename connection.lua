local ircsock = require './ircsock'
local util    = require './util'


---- simple EventEmitter à la Node ----------------------------------
local Conn = { proto = {}, mt = {} }
Conn.mt.__index = Conn.proto


-- adds a listener to an event
function Conn.proto.on(self, event, fun)
  local l = self._listeners

  -- create array if missing, then add listener
  if l[event] == nil then l[event] = {} end
  table.insert(l[event], fun)
end

-- emits an event to all listeners
function Conn.proto.emit(self, event, ...)
  local l = self._listeners

  if l[event] then
    -- call each listener
    for _,fun in ipairs(l[event]) do
      fun(unpack(arg))
    end
  end
end


local function createConnection(config)
  assert(config,           "no config supplied")
  assert(config.hostname,  "must supply hostname")
  assert(config.nick,      "must supply nick")
  assert(config.ident,     "must supply ident")
  assert(config.real_name, "must supply real name")

  config.port = config.port or 6667

  local self = { _listeners = {}
               , config     = config
               , users      = {}
               , channels   = {}
               }

  self.state = { user          = { nick = config.nick }
               , authenticated = false
               }

  setmetatable(self, Conn.mt)

  self.sock = ircsock.open(config.hostname, config.port)
  init_conn(self)

  return self
end

function Conn.proto.join(self, channel)
  assert(type(channel) == 'string', "No channel provided!")
  self.sock:send("JOIN", channel)
end

function Conn.proto.part(self, channel)
  assert(type(channel) == 'string', "No channel provided!")
  self.sock:send("PART", channel)
end

function Conn.proto.nick(self, newnick)
  assert(type(newnick) == 'string', "No new nick provided!")
  self.sock:send("NICK", newnick)
end

function Conn.proto.message(self, target, msg)
  assert(type(target) == 'string', "No target provided!")
  assert(type(msg) == 'string', "No message provided!")

  self.sock:send("PRIVMSG", target, msg)
end

function Conn.proto.notice(self, target, msg)
  assert(type(target) == 'string', "No target provided!")
  assert(type(msg) == 'string', "No message provided!")

  self.sock:send("NOTICE", target, msg)
end

function Conn.proto.ctcp(self, target, ...)
  assert(type(target) == 'string', "No target provided!")
  assert(type(arg[1]) == 'string', "No CTCP command provided!")

  local message = table.concat(arg, " ")

  self.sock:send("PRIVMSG", target, ("\001%s\001"):format(message))
end

function Conn.proto.ctcp_reply(self, target, ...)
  assert(type(target) == 'string', "No target provided!")
  assert(type(arg[1]) == 'string', "No CTCP command provided!")

  local message = table.concat(arg, " ")

  self.sock:send("NOTICE", target, ("\001%s\001"):format(message))
end

function Conn.proto.quit(self, msg)
  self.sock:send("QUIT", msg or "Bye-bye!")
end

function Conn.proto.sendraw(self, raw)
  assert(type(raw) == 'string', "No raw message provided!")
  self.sock:sendraw(raw)
end

function Conn.proto.check(self)
  -- handle eight lines each tick
  for i=1,8 do
    local success, err = self.sock.co()

    if not success and err == "closed" then
      return

    elseif not success then
      return nil, err
    end
  end
end


---- User & channel management functions ----------------------------
local function chan_add(conn, name)
  local entry = { topic = nil
                , users = {}
                }

  conn.channels[name] = entry
  return entry
end

local function user_add(conn, nick)
  local entry = { nick     = nick
                , channels = {}
                }

  conn.users[nick] = entry
  return entry
end

local function user_renick(conn, oldnick, newnick)
  local entry = conn.users[oldnick]

  if entry == nil then
    user_add(conn, newnick)
    return
  end

  entry.nick = newnick

  -- move the 'user' entry
  conn.users[oldnick] = nil
  conn.users[newnick] = entry

  -- move the 'channel' references
  for chan in pairs(entry.channels) do
    conn.channels[chan].users[oldnick] = nil
    conn.channels[chan].users[newnick] = entry
  end
end

local function user_quit(conn, nick)
  local entry = conn.users[nick]

  -- no entry found--silently ignore user_quit
  if entry == nil then return end

  -- remove this user from all channels she's in
  for chan in pairs(entry.channels) do
    conn.channels[chan].users[nick] = nil
  end

  -- remove the user-ref itself
  conn.users[nick] = nil
end


---- Handlers & init_conn -------------------------------------------
function init_conn(self)
  function sys_msg_handler(msg)
    local params  = util.slice(msg.params, 2)
    self:emit("server-msg", table.concat(params, " "))
  end


  local sock = self.sock

  -- add default handler
  sock.no_handler = function(_, msg)
    self:emit("unimplemented", msg)
  end

  sock.handlers["PING"] = function(msg)
    sock:send("PONG", unpack(msg.params))
  end

  sock.handlers["JOIN"] = function(msg)   -- Someone joined a channel
    local nick = msg.source.nick
    local chan = msg.params[1]

    if nick == self.state.user.nick then
      chan_add(self, chan)
      self:emit("self-join", chan)
    end

    if not self.users[nick] then user_add(self, nick) end
    self.users[nick].channels[chan] = { flag=" " }
  --if not self.channels[chan] then chan_add(self, chan) end
    self.channels[chan].users[nick] = self.users[nick]

    self:emit("join", msg.source, chan)
  end

  sock.handlers["PART"] = function(msg)   -- Someone parted a channel
    local nick = msg.source.nick
    local chan = msg.params[1]

    if nick == self.state.user.nick then
      -- we left the channel; remove all associated info since it's now unknown
      self.channels[chan] = nil
      self:emit("self-part", chan)

    else
      if not self.users[nick] then user_add(self, nick) end
      self.users[nick].channels[chan] = nil
      self.channels[chan].users[nick] = nil

      self:emit("part", msg.source, chan)
    end
  end

  -- checks whether the given string represents a channel name
  local function is_channel_name(str)
    local firstChar = str:sub(1, 1)

    return firstChar == "#" or firstChar == "&"
  end

  sock.handlers["PRIVMSG"] = function(msg)
    local target, message = unpack(msg.params)

    -- not a channel, so set target to the sender instead (query)
    if not is_channel_name(target) then
      target = msg.source.nick
    end

    local isCTCP = (message:byte(1) == 1)

    if isCTCP then
      -- remove eventual trailing \001
      if message:byte(#message) == 1 then
        message = message:sub(1, #message - 1)
      end

      local idx  = message:find(" ", 2, true) or #message + 1
      local cmd  = message:sub(2, idx - 1):upper()
      local args = message:sub(idx + 1)

      self:emit("ctcp", target, msg.source, cmd, args)

    else
      self:emit("message", target, msg.source, message)
    end
  end

  sock.handlers["NOTICE"] = function(msg)
    local target, message = unpack(msg.params)

 -- if target == "AUTH" then
    if not self.state.authenticated then
      local u = self.config

      if not self.state.authenticated then
        sock:send("USER", u.ident, "-", "-", u.real_name)
        sock:send("NICK", u.nick)
        self.state.authenticated = true
      end

      sys_msg_handler(msg)
    else
      local isCTCP = (message:byte(1) == 1)

      if isCTCP then
        -- remove eventual trailing \001
        if message:byte(#message) == 1 then
          message = message:sub(1, #message - 1)
        end

        local idx  = message:find(" ", 2, true) or #message + 1
        local cmd  = message:sub(2, idx - 1):upper()
        local args = message:sub(idx + 1)

        self:emit("ctcp-reply", target, msg.source, cmd, args)

      else
        local variant = is_channel_name(target) and "channel" or "direct"
        self:emit("notice", variant, target, msg.source, message)
      end
    end
  end

  sock.handlers["QUIT"] = function(msg)
    local message = unpack(msg.params)

    -- note: we emit 'quit' *before* removing the user & his refs... because
    -- otherwise the handlers can't know which channels the user used to be in.
    self:emit("quit", msg.source, message)

    -- TODO: Handle when *I* quit...
    user_quit(self, msg.source.nick)
  end

  sock.handlers["NICK"] = function(msg)   -- Nick change
    local oldnick = msg.source.nick
    local newnick = unpack(msg.params)

    if oldnick == self.state.user.nick then
      self.state.user.nick = newnick
      self:emit("nick-self", newnick)
    end

    -- record the new name in the users store
    user_renick(self, oldnick, newnick)

    self:emit("nick", oldnick, newnick)
  end

  sock.handlers["001"] = sys_msg_handler  -- Welcome
  sock.handlers["002"] = sys_msg_handler  -- Your host is...
  sock.handlers["003"] = sys_msg_handler  -- Creation date
  sock.handlers["004"] = sys_msg_handler  -- My info
  sock.handlers["005"] = sys_msg_handler  -- Supported things (my capabilities)

  sock.handlers["251"] = sys_msg_handler  -- Curr usage (# users)
  sock.handlers["252"] = sys_msg_handler  -- Curr usage (# opers online)
  sock.handlers["253"] = sys_msg_handler  -- Curr usage (# unknown connections)
  sock.handlers["254"] = sys_msg_handler  -- Curr usage (# channels)
  sock.handlers["255"] = sys_msg_handler  -- Curr usage (# clients and servers)

  sock.handlers["265"] = sys_msg_handler  -- Statistics (# local users)
  sock.handlers["266"] = sys_msg_handler  -- Statistics (# global users)

  sock.handlers["375"] = sys_msg_handler  -- MOTD start
  sock.handlers["372"] = sys_msg_handler  -- MOTD body
  sock.handlers["376"] = function(msg)    -- MOTD end
    sys_msg_handler(msg)
    self:emit("connected")
  end

  sock.handlers["353"] = function(msg)    -- NAMES entry
    local _, kind, chan, nicks = unpack(msg.params)

    local flagMap = { ["@"]="@", ["+"]="+" }

    local users = {}
    for entry in nicks:gmatch("%S+") do
      local firstChar = entry:sub(1, 1)

      local flag = flagMap[firstChar] or " "
      local nick = (flag == " ") and entry or entry:sub(2)

      if not self.users[nick] then user_add(self, nick) end
      self.users[nick].channels[chan] = { flag=flag }
      self.channels[chan].users[nick] = self.users[nick]

      users[nick] = flag
    end

    self:emit("names", chan, kind, users)
  end

  sock.handlers["366"] = function(msg)    -- End of NAMES
    local _, chan, message = unpack(msg.params)
    self:emit("names-end", chan, message)
  end

  sock.handlers["331"] = function(msg)    -- No topic set
    local _, chan, message = unpack(msg.params)
    -- TODO
  --self:emit("topic", chan, nil, message)
  end

  sock.handlers["332"] = function(msg)    -- Topic set
    local _, chan, topic = unpack(msg.params)
    -- TODO
  --self:emit("topic", chan, topic, topic)
  end

  sock.handlers["TOPIC"] = function(msg)  -- Topic changed
    local _, chan, topic = unpack(msg.params)
    self:emit("topic", chan, msg.source, topic)
  end
end


return { open = createConnection }
