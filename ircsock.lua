-----------------------
-- IRC Socket module --
-----------------------

local socket = require 'socket'
local util   = require './util'

--[[
function TEMP_print(...)
--io.write("\027[s\027[60G")
  print(unpack(arg))
--io.write("\027[u")
end
]]


---- Helpers --------------------------------------------------------
local source_mt = { __tostring = function(self) return self.nick end }

-- parses a 'source' part (nick!ident@host) -- not yet implemented! [TODO]
local function parse_source(source)
  local bang = source:find("!", 1, true)
  local at   = bang and source:find("@", bang, true)

  if bang then
    return setmetatable({ nick  = source:sub(1, bang - 1)
                        , ident = source:sub(bang + 1, at - 1)
                        , host  = source:sub(at + 1)
                        }, source_mt)
  else
    return setmetatable({ nick  = "{{" .. source .. "}}"
                        , ident = "<unknown>"
                        , host  = "<unknown>"
                        }, source_mt)
  end
end

local WORD_PATTERN = "[^ ]+"

-- parses a line into a `message` table, which is a structured way to treat
-- the data read from the server.
--
-- Placement of `a` and `b` in the string:
--
--     :tolsun.oulu.fi SERVER csd.bu.edu 5 :BU Central Server
--                     ^a                  ^b
--
local function parse_line(str)
  local a, b   = 1
  local source, params

  -- first, check if first char is colon (handle 'source' part)
  local firstChar = str:sub(1,1)
  if firstChar == ":" then
    local source_part = str:sub(str:find(WORD_PATTERN, 2))
    source = parse_source(source_part)
    a = a + #source_part + 2
  end

  -- then, extract the eventual last param
  b = str:find(":", a, true)
  local lastParam

  if b then lastParam = str:sub(b + 1)
  else      b = #str + 2  -- no last param; default to the whole string for rest
  end

  -- split up the 'rest', add eventual last param
  local rest = util.trim(str:sub(a, b - 1))
  params = util.split(rest, " ")
  if lastParam then table.insert(params, lastParam) end

  -- return result
  local result = { source  = source
                 , command = table.remove(params, 1)
                 , params  = params
                 }

  setmetatable(result,
    { __tostring = function(self)
                     local params = table.concat(self.params, "', '")
                     return ("[%s] ['%s']"):format(self.command, params)
                   end
    })

  return result
end


---- Implementation -------------------------------------------------
-- creates a coroutine that handles reading of the IRC stream
local function get_read_co(self)
--  return coroutine.create(function()
  return function()
 -- while true do
      local line, err = self.sock:receive()

      if err == 'timeout' then
        -- ignore timeout errors (means we have no data to read at the moment)

      elseif err then
     --TEMP_print("irc socket reading loop: " .. tostring(err))
       return nil, err
       -- coroutine.yield(nil, err)

      else
        local msg     = parse_line(line)
        local handler = self.handlers[msg.command]

        -- call handler if one is registered, otherwise print message
        if handler then handler(msg)
        else self:no_handler(msg)
        end
     -- else TEMP_print("-- " .. tostring(msg))
      end

      return true
   -- coroutine.yield()
 -- end
  end
--  end)
end

local IRCSock = { proto = {}, mt = {} }
IRCSock.mt.__index = IRCSock.proto

-- create a new IRCSocket with the given host and port, and open the connection
function IRCSock.create(host, port)
  local self = {}

  self.sock     = assert(socket.connect(host, port))
  self.handlers = {}
  self.co       = get_read_co(self)

  self.sock:settimeout(0.05)
  setmetatable(self, IRCSock.mt)
  return self
end

function IRCSock.proto.no_handler(self, msg)
  print("-- [no handler]: " .. tostring(msg))
end

-- send a RAW line to the server, exactly as is.  Doesn't guard
-- against anything; unsafe!  You should prefer to use `send`.
function IRCSock.proto.sendraw(self, line)
--TEMP_print(">> " .. line)
  self.sock:send(line .. "\r\n")
  return line
end

-- send a command to the server, with the specified command and parameters.
-- Returns nil & error if an error occured, or the string as it is sent to
-- the server if nothing unexpected happened.
function IRCSock.proto.send(self, ...)
  -- make sure that nothing we're sending contains unwanted line breaks
  for _,param in ipairs(arg) do
    if param:find("\r") or param:find("\n") then
      return nil, "Command parameter contained line break!"
    end
  end

  -- prepend colon to last parameter
  if #arg > 1 then
    local lastParam = table.remove(arg)
    table.insert(arg, ":" .. lastParam)
  end

  return self:sendraw(table.concat(arg, " "))
end

return { IRCSock = IRCSock
       , open    = function(host, port)
                     return IRCSock.create(host, port)
                   end
       }
