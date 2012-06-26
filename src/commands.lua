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
  local message = table.concat(arg, " ")
  conn:message(target, message)
end

commands["notice"] = function(conn, target, ...)
  local message = table.concat(arg, " ")
  conn:notice(target, message)
end

commands["ctcp"] = function(conn, target, ...)
  conn:ctcp(target, unpack(arg))
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

