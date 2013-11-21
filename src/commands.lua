--------------------
-- slash commands --
--------------------

commands["join"] = function(conn, chan)
  conn:join(chan)
end
commands["j"] = commands["join"]

commands["part"] = function(conn, chan)
  chan = chan or view.active.name
  conn:part(chan)
end

commands["hop"] = function(conn, chan)
  chan = chan or view.active.name
  conn:part(chan)
  conn:join(chan)
end

commands["msg"] = function(conn, target, ...)
  local message = table.concat({...}, " ")
  conn:message(target, message)
end

commands["notice"] = function(conn, target, ...)
  local message = table.concat({...}, " ")
  conn:notice(target, message)
end

commands["ctcp"] = function(conn, target, ...)
  conn:ctcp(target, ...)
end

commands["me"] = function(conn, ...)
  local message = table.concat({...}, " ")
  local target  = view.active.name
  conn:action(target, message)
end

commands["ping"] = function(conn, target)
  conn:ctcp(target, "PING", tostring(os.time()))
end

commands["version"] = function(conn, target)
  conn:ctcp(target, "VERSION")
end

commands["nick"] = function(conn, newnick)
  conn:nick(newnick)
end

