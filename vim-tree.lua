---- Helpers --------------------------------------------------------
local function empty_fn() end


---- Tree -----------------------------------------------------------
-- TODO: Right now, the Tree is more of a List... and it only supports appending
--       new entries at the end of the list.
local Tree = { proto = {}, mt = {} }
Tree.mt.__index = Tree.proto


-- Append a new entry to the tree
function Tree.proto.append(self, entry)
  assert(type(entry)      == 'table',  "entry must be table")
  assert(type(entry.name) == 'string', "entry.name must be string")

  entry.label    = entry.label    or entry.name
  entry.padding  = entry.padding  or ""
  entry.status   = entry.status   or " "
  entry.callback = entry.callback or empty_fn

  -- add it!
  entry.line = #self.buf + 1
  self.linemap[entry.line]  = entry
  self.entrymap[entry.name] = entry

  -- add to UI
  local full_label = ("%s%s %s"):format(entry.padding, entry.status, entry.label)
  self.buf:insert(full_label, entry.line)
end

-- Update an existing entry in the tree by name (or by line)
function Tree.proto.update(self, updates)
  assert(type(updates)      == 'table',  "updates must be table")
  assert(type(updates.name) == 'string'
      or type(updates.line) == 'number',
         "must provide either entry-name or entry-line")

  local entry = self.entrymap[updates.name] or self.linemap[updates.line]
  if entry == nil then
    return nil, ("No such entry: '%s' (id: %s)"):format(tostring(updates.name),
                                                        tostring(updates.line))
  end

  -- copy over the new values
  for k,v in pairs(updates) do
    entry[k] = v
  end

  -- update UI
  local full_label = ("%s%s %s"):format(entry.padding, entry.status, entry.label)
  self.buf[entry.line] = full_label
end

-- Get an entry by entry-name or entry-line
function Tree.proto.get(self, query)
  assert(type(query) == 'table', "updates must be table")
  if type(query.name) ~= 'string' and type(query.line) ~= 'number' then
    error("must provide either entry-name or entry-line", 2)
  end

  local entry = self.entrymap[query.name] or self.linemap[query.line]
  if entry == nil then
    return nil, ("No such entry: '%s' (id: %s)"):format(tostring(query.name),
                                                        tostring(query.line))
  end

  return entry
end

-- Get an iterator over all the entries
function Tree.proto.entries(self)
  return pairs(self.linemap)
end

-- Append separator to the tree
function Tree.proto.append_separator(self)
  self:append({ name="--", type='separator', label="" })
end

-- Switch to the given line.  Used by 
function Tree.proto.switch(self, line)
end

do
  local treelist = {}

  -- wraps a window to act as a tree view
  function Tree.wrap(win, title)
    local currBuf = vim.buffer()

    title = title or "Tree"

    local id     = #treelist + 1
    local widget = setmetatable({ id       = id
                                , win      = win
                                , buf      = win.buffer
                                , linemap  = {}
                                , entrymap = {}
                                }, Tree.mt)
    table.insert(treelist, widget)

    widget.buf()
    vim.command(("noremap <buffer> o :lua irc_tree_switch(%d)<CR>"):format(id))

    win.buffer:insert(title, 0)

    currBuf()
    return widget
  end

  -- used as a callback from Vim-world
  function irc_tree_switch(id)
    local widget = treelist[id]
    local line   = widget.win.line

    assert(widget, "No tree with ID " .. tostring(id) .. " found.")

    local entry = widget.linemap[line]

    -- silently ignore non-existing entries
    if entry then
      entry:callback()
    end
  end
end

---- Exposed stuff --------------------------------------------------
return { Tree = Tree }
